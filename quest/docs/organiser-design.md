# Player-organised quests: design

Proposal, 2026-11-06, for WoW Forever build 1.60.1.70790. Nothing here has been built or run in-game. API references were checked against Blizzard's source for this build. Counts come from `python -I quest/tools/research/quest_categories_test.py` and cover the 4,244 vanilla quests in QuestieDB, so new Forever quests aren't measured.

## Goal

Every quest in the log is in the tracker, in a tree the player opens as needed. The game's own headers sort quests automatically, the player's own groups override that, and nothing rearranges itself behind their back. A quest in one of the player's groups is tracked, in the game's sense. The rest sit under Journal, untracked.

Categories and groups start collapsed. Journal itself starts open, so its categories show. Here `<<` is the double arrow of something closed and `vv` of something open:

```text
Tous les objectifs   [réglages] [cadenas] [loupe] [filtre] -
Suivi                              [+]  1/3   <<
Journal                                2/13   vv
    Monde                               2/9   <<
    Donjons et raids                    0/3   <<
    Classe et métiers                   0/1   <<
```

Opened as far as you need:

```text
Tous les objectifs   [réglages] [cadenas] [loupe] [filtre] -
Suivi                              [+]  1/3   vv
    À faire plus tard        [oeil]     0/1   <<
    À faire maintenant       [oeil]     1/2   vv
        [7] Les bougies de kobolds        [objet]
          - Grandes bougies : 3/8
        [2] Nettoyer le camp des kobolds
          ✓ Vermine kobold : 10/10
Journal                                2/13   vv
    Monde                               2/9   <<
    Donjons et raids                    0/3   vv
        Les Mortemines       [oeil]     0/2   vv
            [17] Les masques rouges en soie
              - Bandanas de soie rouge : 3/10
            [22] La Confrérie défias
              - Objectif : 0/2
        Cavernes des lamentations [oeil] 0/1  <<
    Classe et métiers                   0/1   <<
```

Titles and levels are real quests from QuestieDB. The layout is a sketch. Objective text and numbers are illustrative.

## Existing addons

I found no Forever addon that confirms player-defined groups, on 2026-11-06 and again on 2026-11-09. Apart from QuestSections, whose code I read, this comes from listing pages and search summaries, and I haven't run any of them. On 2026-11-09 I read CurseForge's results for "quest tracker" and "quest groups", and the full pages of Kaliel's Tracker, Nullgate's and Duskwatch. Downloads are CurseForge's counts that day; rows marked "Not checked" are from 2026-11-06.

| Addon | Downloads | What it offers | What's missing for this goal |
| --- | --- | --- | --- |
| Kaliel's Tracker | 2.2M, mostly from retail | The long-standing replacement tracker, for Retail and Forever (its page names 1.60.1): filters, module order, quest item buttons plus one for the nearest quest's item, styling, support for TomTom, Auctionator, RareScanner and others | No player groups on its page |
| Nullgate's Quest Tracker - Forever | 5.7K | A standalone tracker: zone groups, a Zone / All switch, filters and sorting, item buttons that work in combat, a guide arrow with `/way`, XP and location bars, quest automation, themes, profiles, 11 languages | Groups come from zones |
| Improved Forever: Quest Tracker | 2.3K | Sorting by zone, level, title, distance or completion, gamepad support, a sound when an objective completes | No player groups mentioned |
| Queston Forever | 1.1K | Blizzard-styled, like this addon: zone groups, filters, search, quest givers and turn-ins on the map and minimap, waypoints, gamepad support | Groups come from zones |
| Duskwatch | 550 | Retail first, Forever support new, needs the Exquisite addon. Sections by kind (Focused, Ready to Turn In, Current Zone, Campaign...) dragged into any order, and small separate trackers per kind of content | Sections are kinds of content, not player groups |
| QuestTags Forever | 205 | Quest type tags, sorting, filters and location groups on Blizzard's tracker | Groups come from locations |
| PrimeQuestTracker | 89 | A compact tracker for Forever and Retail, in three groups: Campaign, Dungeon and Other | Three fixed groups |
| QuestSections Forever | 86 | Fixed sections (class, dungeons, zones) on Blizzard's tracker, sorted easiest to hardest | The only manual control is `/qs assign <id> <name>`. No way to order sections or quests by hand |
| BetterTracker | Not checked | Zone groups from the quest log's categories, sorting, colours | Groups come from the client |
| EQ - Objective Tracker | Not checked | A manual order you drag into place, among 8 sort orders | No custom groups mentioned |
| QuestLog Manager | Not checked | Multi-select in the quest log, bulk abandon | Not about grouping |
| Personal Quest Log | Not checked | Custom groups, deprecated | For the player's own goals, not game quests |

Also seen on 2026-11-09, with no grouping in their one-line summaries: EnhancedQuestTracker (1.8K), Forever Quest Tracker (609), Magic Quest Tracker (570), BetterQuestTracker (476) and JTS Quest Tracker (272). At least twelve trackers say they run on Forever, and each one that groups game quests does it by itself, apart from QuestSections' `/qs assign`.

## Core rules

1. **Every quest in the log appears.** Those in the player's groups are tracked, and the rest sit under Journal, untracked. See [Tracked means in a group](#tracked-means-in-a-group).
2. **A fixed tree.** Suivi holds the player's groups. Journal holds categories, and categories hold groups. Groups hold quests. Player groups don't nest, as agreed, and the levels are fixed, not something a player can extend.
3. **Categories and groups start collapsed, and the addon remembers what you open.** Opening a group shows its quests with their objectives, as Blizzard's tracker does. Quests themselves don't collapse.
4. **A quest appears once.** In the player's group if it's there, otherwise under its automatic category and header. A quest in a group also leaves one grey line in its automatic place. See [Quest rows](#quest-rows).
5. **Nothing moves by itself.** Rows change position only from a player action, a newly accepted quest, a change to what the game tracks, or a zone change reordering zone headers. Progress and completion never reorder anything, and nothing opens by itself except the focused quest's group and a first group the addon has just created.
6. **Layouts belong to a character,** because quest logs do.
7. **A layout must survive client restarts, addon updates and game patches.** This is a hard requirement. See [Surviving launches and updates](#surviving-launches-and-updates).
8. **The whole tracker is rewritten, and nothing Blizzard's tracker does is lost.** [tracker-parity.md](tracker-parity.md) lists all 188 features, in every section that can fill on Forever.
9. **Filters and search only hide rows.** They never move a quest or change a group. See [filter-search.md](filter-search.md).
10. **Other addons can add to the tracker** without either side having to name the other. See [addon-extensions.md](addon-extensions.md).
11. **Everything in the tracker is in the client's language,** Ikar's ruling on 2026-11-06. See [Names](#names).

## Categories

**Most quests sort themselves,** because the quest log already gives each one a header. The addon reads that header, and the header decides both the category and the group inside it. Vanilla quests split like this:

| Category | Groups inside | Quests | Share |
| --- | --- | --- | --- |
| Suivi (`TRACK_QUEST_ABBREV`), Ikar's ruling on 2026-11-06 | Each of the player's groups | The player's choice | |
| Journal, Ikar's ruling on 2026-11-06 | Every category below, as one section that collapses whole | Everything not in a group | |
| Monde (`WORLD`) | One per zone: 60 headers, including capitals | 2,500 | 58.9% |
| Classe et métiers (`CLASS`, `TRADE_SKILLS`) | Your class, then one per profession | 620 | 14.6% |
| Donjons et raids (`DUNGEONS`, `RAIDS`) | One per dungeon or raid: 26 headers | 558 | 13.1% |
| Évènements (`EVENTS_LABEL`) | Guerre d'Ahn'Qiraj, Fête lunaire, Saisonnier, Foire de Sombrelune, Invasion, Solstice d'été | 304 | 7.2% |
| Champs de bataille (`BATTLEGROUNDS`) | Vallée d'Alterac, Bassin Arathi, Goulet des Chanteguerres | 202 | 4.8% |
| Divers (`MISCELLANEOUS`) | Réputation, Spécial, Légendaire, Épique, Carte au trésor | 60 | 1.4% |

**The last three are the answer to "are there quests other than zone, profession, class or dungeon?"** Yes: 566 quests, or 13.3%. Ikar's decision: they stay three separate categories. A category with no quests in your log doesn't show, so a typical character sees three or four bars.

`QuestSort` also holds Incursions de cauchemar and Éruption de Blackrock, which belong in Évènements, and L'Ordre suprême, Campement and Elfe de la nuit, which belong in Divers. No vanilla quest uses them, so they may be Forever content.

### How a header is classified

**By its key first, since 2026-11-09.** A header's `headerSortKey` holds its ID: 0x40000000 plus the `AreaTable` ID for a zone or an instance, 0x20000000 plus the `QuestSort` ID for the rest. Blizzard doesn't document it, but its quest map saves each header's open state under it. The ID decides in any language:

- An area is an instance or a battleground when its ID is in the lists of steps 3 and 4, otherwise a zone.
- A `QuestSort` is your class when it's `Categories.CLASS_SORT[classFile]`, otherwise a class, profession, event or miscellaneous header, from `QuestSort`. One the data doesn't know goes to Divers, because a `QuestSort` header is never a zone. My call on 2026-11-09.

**By its name otherwise,** for a key of another shape, in this order, stopping at the first match:

1. Your class's masculine name, `LOCALIZED_CLASS_NAMES_MALE[classFile]`, because `QuestSort` uses the masculine form in French. See [quest-properties.md](quest-properties.md).
2. A profession's `QuestSort` name.
3. An instance, from a list of area IDs translated live by `C_Map.GetAreaInfo`: the headers vanilla quests use, and every top-level area of a dungeon or raid map. The second half came after Ikar found Forever's own dungeon quest "Incursion dans le Vieux Forgefer" under Monde on 2026-11-07: its header, La salle des Thanes (area 16919), is a dungeon no vanilla quest uses.
4. A battleground, the same way.
5. An event or miscellaneous `QuestSort` name.
6. **Anything else is a zone, under Monde.** A new unknown header therefore lands somewhere sensible.

`QuestSort` names have no API, so steps 2 and 5 need a small table per client language, from Blizzard's `QuestSort` table. It stays as the fallback until a class and a profession header have been seen with their key in game.

### What a header can't tell

| Case | Quests | What happens |
| --- | --- | --- |
| Tagged dungeon or raid, under another header | 147: Monde 107, Classe et métiers 32, Divers 7, Évènements 1 | **The game doesn't say which dungeon,** so they can't join a dungeon's group. They stay under their header with a dungeon or raid marker. The player can move them |
| Class-restricted, under another header | 297: Donjons et raids 217, Monde 74, Divers 4, Évènements 2 | Those in instances are right where they are. The 74 in zones stay there, unless tag 21 identifies them |
| Needs a profession, under another header | 28: Monde 25, Évènements 2, Donjons et raids 1 | Stay under their header. No marker exists for this |

The first case includes quests such as "The Test of Righteousness" (Paladin) and "Hot Fiery Death" (Forgeron), which send you into a dungeon but belong to a class or profession. So the header is usually a fair place for them.

### Details

- **Order of the bars:** Suivi first, Ikar's decision, then Journal. Neither moves. The categories inside Journal start in the table's order and can be dragged into another.
- **Order inside:** Monde lists the zone you're in first, updated on zone change, then the other zones alphabetically. Donjons et raids and the others are alphabetical. The player's groups keep the player's order. Monde's other zones followed the log's order until 2026-11-09, when Ikar saw them shift on opening a Sombrivage quest: the game re-sorts its log for the map it shows (`QuestLogMixin:Refresh` in `QuestMapFrame.lua` sets the map, then calls `SortQuests`), so opening a quest on the map moved that quest's zone up.
- **Other sections stay as bars of their own,** such as recipes ("Métier") and achievements ("Hauts faits"), below Journal. Recipes you track aren't the same thing as profession quests.
- **Depth is five levels under Suivi and six under Journal:** title, Journal, category, group, quest, objective. Journal adds a level Blizzard's art wasn't drawn for, so the bars inside it are dimmer, and Suivi and Journal read as the two top sections. All of them use Blizzard's section bar in place of its single "Quêtes" bar, so the tree costs no extra indent.
- **Open and closed look the same on bars and groups,** Ikar's ruling on 2026-11-06. There are no + and − buttons. A double arrow at the right of the line points left when closed and down when open, in the same column on every line, with the counts lined up to its left. The art is `CovenantSanctum-Renown-DoubleArrow`, which points left, so open turns it a quarter with `Texture:SetRotation`, as Blizzard's radial wheel does on an atlas texture. It also has `-Hover` and `-Depressed` versions. It needs judging in-game, because it comes from another panel and has only been seen on the bench. The title row's collapse-all is the same double arrow, Ikar's ruling on 2026-11-07, and the filter beside it a plain icon, `gamepad-hud-icon-filter`, like the magnifying glass, not Blizzard's red button.
- **Suivi tucks under the title,** Ikar's ruling on 2026-11-06, who found the space between them wasted. Blizzard starts its first section 6 below the 32-high title. Here Suivi starts 4 inside it, so 10 units higher, and its bar's dark band meets the title's lower edge. With the search box, its status line or a popup showing, those sit at Blizzard's 6 instead, so nothing overlaps the title. The bar's padding above it, there for art that pokes out, lets clicks through to the title's buttons. The title is drawn above the list, and rows scrolling up are clipped at the title's lower edge, as are the scrollbar and item buttons, so nothing shows through it. It's the advanced option "Under the title".

### Names

Everything shown in the tracker is in the client's language, English included only on an English client. **The game's own strings come first,** so they translate themselves: `TRACKER_ALL_OBJECTIVES`, `TRACK_QUEST_ABBREV` for Suivi, `QUESTS_LABEL`, `WORLD`, `EVENTS_LABEL`, `BATTLEGROUNDS`, `MISCELLANEOUS`, `OBJECTIVES_STOP_TRACKING`, `TRACK_QUEST`. **Labels with no exact game string go in the addon's own table, per language, French first:** Journal, Classe et métiers, Donjons et raids, Nouveau groupe, Déplacer vers, Fermer les autres and the like. On an English client `TRACK_QUEST_ABBREV` reads "Track", so that table can replace it there.

## Tracked means in a group

Ikar's decision, 2026-11-06, replacing the earlier one to ignore the game's tracked list. **A quest in one of the player's groups is tracked. Every other quest is untracked and sits under Journal.** The groups and the game's list follow each other, so the quest log's checkbox, other addons, and Blizzard's tracker if the addon is disabled all agree with what the player sees.

| What happens | What follows |
| --- | --- |
| The player puts a quest in a group | `C_QuestLog.AddQuestWatch` |
| The player takes it out, or deletes its group | `C_QuestLog.RemoveQuestWatch` |
| The game starts tracking a quest that's in no group: auto-tracking, the quest log's checkbox, a map button, another addon | It joins the end of the top group, Ikar's ruling. **With no groups at all, the addon creates one,** open, also Ikar's ruling. It's named with the game's `QUESTS_LABEL`, "Quêtes", because a group called Suivi would sit inside the Suivi section. It's an ordinary group after that |
| The game stops tracking a quest in a group | It leaves the group for its place under Journal |
| Login | In a group but untracked: `AddQuestWatch`, group by group from the top, so the top groups get the 25 slots. Then tracked and in no group: as above, so a first run puts everything tracked in "Quêtes". IDs missing from the log are left alone, because the log can read as empty during login. Nothing is followed until this has run |
| Any of this during combat | The row waits until combat ends, like other row changes |

What this brings with it:
- **Changes settle on the next frame, by comparing lists.** DialogueUI's `RemoveQuestObjectiveTrackerQuestPopUp` flips a quest's watch off and on, or on and off, in one call, to fire `QUEST_WATCH_LIST_CHANGED`. Acting on each event would throw a quest out of its group, or into one. And this build marks that event `UniqueEvent`, so several changes in one frame, such as the log's "track all" on a header, may arrive as one event. So the handler ignores what the event says: on the next frame it reads the whole list and compares it with the last one it followed. A quest newly on it joins the top group; one that left it while still in the log leaves its group. A placed quest the game never tracked, past its 25, is never on either list, so it stays put.
- **The game's limit is 25.** `MAX_QUEST_WATCHES` is 25, and past it `AddQuestWatch` adds nothing and auto-tracking stops, so new quests stay under Journal. A quest the player places by hand stays in its group anyway, off the game's list, so the layout never depends on the limit.
- **Auto-tracking is off by default,** Ikar's ruling on 2026-11-06. With the game's `autoQuestWatch` on, Blizzard tracks every accepted quest, in `Blizzard_ObjectiveTracker.lua:35`, and every quest whose objectives move, in `QuestMapFrame.lua:584` on `QUEST_WATCH_UPDATE`. Each would land in the top group, and Suivi would turn back into Blizzard's flat list while Journal's sorting went unused. So the addon turns it off at install and offers it as an option. See [Options](#options).
- **A map button tracks.** `POIButton.lua` calls `AddQuestWatch` on an untracked quest before focusing it, so a map button on a Journal quest moves it into a group. The menu's Focalisation doesn't.
- **Stopping tracking clears focus.** `OnQuestWatchChanged` in `Blizzard_QuestSuperTracking.lua` clears the focused quest if it's the one untracked.
- **Untracking follows Blizzard's check.** The addon's entries use `QuestUtil.CanRemoveQuestWatch`, which refuses for players in the New Player Experience. Forever ships one (`Blizzard_NewPlayerExperience/Camelot`). There, deleting a group with tracked quests and taking a tracked quest out are refused, because the quest would stay tracked and come back into the top group. Moving between groups still works.
- **Task and bounty quests are left out** of the list the addon follows, as Blizzard's own auto-tracking skips them.

| What else reads the list | Effect |
| --- | --- |
| Blizzard's map | None found on what's shown. `QuestDataProvider` refreshes on the list's event, but `ShouldShowQuest` doesn't check it, and no map provider does for ordinary quests. The minimap and quest area event run in the client's own code, so they need an in-game check |
| Blizzard's tracker, if the addon is disabled | Shows what was in the player's groups |
| Zmap's quest panel | Its checkbox now moves quests in and out of the player's groups |
| LoreForever's strip and journey | Read the first tracked quest. That isn't the first in the player's groups: Blizzard's tracker calls `C_QuestLog.SortQuestWatches` on every zone change, which orders the list by distance |

I rejected something similar earlier: treating "open" as "tracked". This is different, because being in a group opens nothing, so auto-tracking doesn't open rows and the limit doesn't cap what can be open.

**What this costs, compared with Blizzard's tracker:** the list can be taller than the screen. At three lines per quest and text size 12, by my estimate, an open group of 5 to 10 quests takes about 300 to 600 pixels, and a log of 40 with everything open about 2,700, against Edit Mode's 1,000 maximum. So the tracker scrolls, which Blizzard's doesn't, with the mouse wheel and Blizzard's 8-pixel `MinimalScrollBar`. It sits right of the rows and is invisible unless the list is scrolling or the pointer is on it, as Ikar ruled. Ikar's screenshots put the tracker's right edge 5 units from the edge of the screen, so the rows sit 12 units further in to leave the bar room. See [Options](#options).

Objectives are hidden only inside a closed group. That comes from starting collapsed, not from anything to do with tracking.

## Quest rows

```text
[carte] [2] [11+] Titre de la quête      [icônes] [partager] [objet] [œil]
  - Objectif : 3/8
```

| Part | Shows | Source |
| --- | --- | --- |
| Map button | Focus, and complete or in-progress state | Blizzard's template. Complete shows the turn-in icon |
| `[2]` | Party members on the quest | `QuestUtils_GetNumPartyMembersOnQuest`, as the native log does |
| `[11+]` | Level, `+` for elite, colour for difficulty | `SetQuestTitleLevelAndDifficultyColor`, as native |
| Icons | See [Markers](#markers) | |
| Share button | See below | |
| Item button | As native, 26 pixels, placed over the row rather than inside it. See [Combat](#combat) | `GetQuestLogSpecialItemInfo` |
| Eye | Find a group, as native | `QuestUtil.CanCreateQuestGroup` |

**The quick share button** is only there when it can do something: you're in a group, the quest is shareable, and at least one party member doesn't have it. Solo, it never appears.

```lua
IsInGroup() and C_QuestLog.IsPushableQuest(questID)
    and QuestUtils_GetNumPartyMembersOnQuest(questID) < GetNumSubgroupMembers()
```

Clicking calls `QuestUtil.ShareQuest(questID)`, as Blizzard's menu does, and the game's own `ERR_QUEST_PUSH_*` messages report the results. The party count needs refreshing on `GROUP_ROSTER_UPDATE` and `UNIT_QUEST_LOG_CHANGED`. Blizzard has no share icon for this, so the art is `socialqueuing-icon-group` on `QuestSharing-QuestLog-Button`, to be judged in-game.

**The level is a coloured number on a dark rectangle,** Ikar's ruling on 2026-11-06, who found difficulty-coloured titles too busy, "a Christmas tree". It sits in a column left of the title, so a wrapped title keeps its left edge, and its colour carries the difficulty. Titles are all one colour. The number says the same thing as the colour, so colour isn't the only signal. With the game's difficulty colours off, the number takes the title's colour. Rejected after trying them on the test bench: white or black text on a coloured badge. **The number sits on Forever's own nameplate level art,** `UI-HUD-Nameplates-LevelIndicator`, Ikar's pick on 2026-11-08 among 20 proposals on the bench: Forever's nameplates show a level the same way, its number coloured by difficulty (`CompactUnitFrame.lua` 1521-1535). It's stretched to the column, 1.75 by 1.3 times the text size, as the nameplates stretch it, centred on the title's first line, with the number at 0.75 of the text size. It replaces the black rectangle at 40% of 2026-11-06.

**The whole box is one target,** Ikar's ruling. Click, right click and drag work anywhere on a quest's box, including its objectives and badge. Only the buttons on it keep their own click. Blizzard's only responds on the title text.

**A moved quest leaves a line behind,** Ikar's ruling on 2026-11-06. When a quest is in one of the player's groups, its own section keeps one grey line with its title, in the quest's usual place, cut with "…" if it's too long. Clicking and right-clicking the line do what they do on the quest's row. A button at its right end, `common-icon-undo`, takes the quest out of the group and back to that spot, as Arrêter le suivi does, but not in combat. The line has no objectives, markers or other buttons, isn't counted, and can't be dragged. A section left with only such lines stays, with no count. Search and filters hide the lines, because the quest is already listed in its group. Forever Quest Tint will mark the line too, but a cut title can hide its mark.

**Quests touch,** Ikar's ruling on 2026-11-06, with no gap between them and one thin line of the game's art where their backgrounds meet: `Options_HorizontalDivider`, the 1-unit divider from Blizzard's options panels, which exists in both art sets, at half its brightness. The list has one more line above its first quest and one below its last, Ikar's ruling on 2026-11-06. Grey lines of moved quests get the same lines.

**A background behind each quest** is a plain rectangle, with its own opacity at rest, in combat, and on hover or when clicked. A focused quest also counts as clicked, because with map buttons off nothing else shows focus. The opacities are options; see [Options](#options).

**Popups and the timer keep Blizzard's full-size look,** Ikar's ruling after trying one-line versions on the test bench. Both are centred in the panel and scale with the text, up to the panel's width, so they stay on screen.

**Group names, counts and objectives are quieter,** so the bars stay the only gold, Ikar's ruling on 2026-11-07.

## Markers

**An icon shows only when the row's position and text don't already say it.** Measured on vanilla quests, **81.9% of rows show no icon, 18.0% show one, and 0.2% show two.** Group size and timed quests aren't in the data, so they'd add a little.

| Marker | Shows when | Icon | Vanilla quests |
| --- | --- | --- | --- |
| Off the game's list | In one of the player's groups, past the game's 25 tracked quests | `waypoint-mappin-minimap-untracked`, "(Hors liste)" as text | Live |
| Timed | The quest has a timer | `questlog-questtypeicon-clockyellow` | Not measured |
| Group size | `suggestedGroup` above 1, with the number | `questlog-questtypeicon-group` | Not measured |
| Dungeon | Tag 81, outside Donjons et raids | `questlog-questtypeicon-dungeon` | 108 |
| Raid | Tag 62, or 88 and 89 for 10 and 25 players, outside Donjons et raids | `questlog-questtypeicon-raid` | 39 |
| PvP | Tag 41, outside Champs de bataille | `questlog-questtypeicon-pvp` | 20 |
| Repeatable | `IsRepeatableQuest` | `QuestRepeatableTurnin` | 609 |
| Daily | `frequency` 1, or 3 for scheduled | `questlog-questtypeicon-daily` | 0 |
| Weekly | `frequency` 2 | `questlog-questtypeicon-weekly` | 0 |
| Legendary | Tag 83 | `questlog-questtypeicon-legendary` | Not counted |
| Class | Moved into Suivi from a class header, or tag 21 if it works | `questlog-questtypeicon-class` | Live |

When a quest moves to Suivi, its position stops saying anything, so its dungeon, raid, PvP and class icons appear.

**Not icons, because something better already exists:** elite is the `+`, difficulty is the title's colour, complete is the map button, failed is the word "Echec" under the title, and party members are `[2]`. **Tooltip only:** shareable, story, storyline, breadcrumb, account-wide, faction and rewards.

**Decided: icons, not the `(Donjon)` text, for dungeon, raid and PvP,** by Ikar on 2026-11-06. On Forever, Blizzard's own titles end in `(Élite)`, `(Donjon)`, `(Raid)` or `(JcJ)` (`QuestUtilsOverrides.GetQuestTagText`), which would say the same thing as the icon. The rows leave that text out, which also leaves more room for French titles. **The other markers stay,** Ikar on 2026-11-08: I had read this ruling as dropping them, which it never did.

**A usable item behind a closed group: dropped, Ikar's ruling on 2026-11-08.** The idea was a closed group showing the highlight's arrow and count when an item inside it becomes usable, even with the area highlight off. With the highlight on, the closed group already counts that quest; with it off, the player chose not to be flagged.

**Off the game's list,** Ikar's ruling on 2026-11-06. A quest placed by hand past the game's 25 stays in its group but isn't tracked in the game's sense, so it may lose its map pin and minimap area. It comes first among the markers. Its name, "Au-delà des 25 quêtes suivies par le jeu", showed in the row's tooltip until Ikar's ruling on 2026-11-10 (below); the Texte style reads "(Hors liste)". The icon is the minimap's untracked waypoint pin. Keep it only if risk 4 shows such quests really lose their pin.

At most three icons show on a row, in the table's order. **No tooltip names them,** Ikar's ruling on 2026-11-10 ("No tooltip, icons only"): until then hovering a row with markers showed its title and their names, which a fourth marker now loses. A setting offers Icons, Text or None, built on 2026-11-08 with Ikar's go-ahead: text reads "(Donjon)", "(5)" for a group size, or "(Hors liste)", in grey, and None shows nothing. Each marker can also be switched off on its own, in the options page's "Marqueurs affichés" section, built on 2026-11-08 with Ikar's go-ahead: one switched off doesn't show. The icons' native size is 18 to 32 pixels, so how small they stay readable needs judging in-game. The rest of the classification list is in [quest-properties.md](quest-properties.md).

## Management features

### Version 1

| Feature | How it works |
| --- | --- |
| Create a group | The + on the Suivi bar, Ikar's ruling on 2026-11-06. Or right-click a quest: Déplacer vers > Nouveau groupe, or use the menu of the Suivi bar or a group. The new group goes last, open, scrolled into view and named in place. The bar shows even with no groups, so the first one can be made this way |
| Rename a group | Edit in place on the row. Enter saves, Escape cancels, an empty name cancels |
| Delete a group | Its quests return to their automatic place. Asks first only if it holds quests. Refused in combat, Ikar's ruling on 2026-11-06, because every row below it would move. **No line stays in its place,** Ikar's ruling on 2026-11-08, which found the grey "« nom » supprimé" line of 2026-11-06 noisy: the gear's menu offers "Annuler la suppression de « nom »" first instead. Undo brings the group back in its place, open or closed as it was, with its quests tracked again, except any that joined another group since. Refused in combat, as the gear is. It's offered until it's used, another group is deleted, or the UI reloads, and isn't saved. `/kq group undo` does the same |
| Move a quest | Right-click > Déplacer vers, or drag it, into one of the player's groups |
| Move several quests | Ctrl+click picks quests, Ikar's request on 2026-11-08; see [Interaction](#interaction). A picked row's drag or menu then acts on them all, in the order they show |
| Put a quest back | Arrêter le suivi, or the button on its grey line, which returns it to its automatic place under Journal |
| Move a quest from the log | Dropped, Ikar's ruling on 2026-11-07: no need to change the native quest log |
| Reorder | Drag quests within a player's group, player's groups, and the category bars inside Journal. Automatic groups keep their own order |
| Open and close | Click anywhere on a category's or group's line. A double arrow at its right shows which it is. State is remembered, and a closed header keeps its count, such as 1/3 |
| Open or close everything inside | Menu on a bar, including Journal: Tout ouvrir, Tout fermer |
| Focus a group | The eye on any group, Ikar's ruling on 2026-11-06, or Fermer les autres in its menu. It opens that group and closes every other. It sits left of the count and uses `GM-Icon-Visible`, a plain eye, so it doesn't read as the green find-group eye on quests |
| Key bindings | Ikar's ruling on 2026-11-06, in the game's Key Bindings under AddOns, unbound as addon bindings ship: lock or unlock, collapse or expand all, previous group, next group. Each does what its click does, lock included. Next and previous step through the player's groups as the eye does, opening the tracker and Suivi if needed and wrapping round at the ends. `Bindings.xml`, with `BINDING_HEADER_` and `BINDING_NAME_` strings in the addon's own table |
| Choose where new quests go | Newly tracked quests join the top group, Ikar's ruling on 2026-11-06, so dragging another group to the top changes where they go. Untracked ones stay in their automatic place |
| Follow-up quests stay together | A quest accepted from the same NPC within 2 minutes of turning in a placed quest takes its slot |
| Repeatable quests keep their place | A daily returns to its group and position when accepted again |
| Scrolling | Mouse wheel and scrollbar, when the list is taller than the tracker |
| Full tracker features | From [tracker-parity.md](tracker-parity.md) |
| Filter by classification | A menu of checkboxes offering only values your quests have. See [filter-search.md](filter-search.md) |
| Search | Text anywhere in a quest, ignoring case and accents. See [filter-search.md](filter-search.md) |
| Other addons | See [addon-extensions.md](addon-extensions.md) |

**Where a newly accepted quest goes, in order:**
1. Its saved place, if the player placed it before.
2. A placed predecessor's slot, under the follow-up rule.
3. If the game tracks it, which only happens with the auto-tracking option on, the top group, or a new "Quêtes" group if there are none.
4. Its category and header, under Journal.

It doesn't open anything, apart from a first group it has just created. The closed header's count goes up and plays one short glow, so a new quest is noticed without rows moving.

### Area highlight: optional, on by default

On by default since Ikar's defaults of 2026-11-07. **Written on 2026-11-07, Ikar's go-ahead, tested offline only,** in `UI/Area.lua`. When you're in a quest's area, its row brightens and gains a small arrow (`poi-traveldirections-arrow`), and every closed header above it counts how many quests are here. Entering the area plays one short glow. **Nothing moves and nothing loops,** so it keeps rule 5. With everything collapsed, this is how the tracker points you at what's relevant nearby.

As built:
- **The row:** the arrow before the title, sized with the text, and the title and objectives in the hover's white. The moved quest's grey line stays as it is.
- **The headers:** the arrow and the number, white, left of a group's eye and left of a bar's count, as on the bench. The bench shows it on open headers too, so the addon does: an open Journal or category then still says how many are here among its groups.
- **The glow:** the row's title glows up and down once, as a closed header's flash does; a quest whose row isn't drawn makes the nearest drawn header glow instead. The first check after a login, a reload or switching it on only notes what's here, so nothing glows then.
- **The check:** once a second while it's on and the addon's tracker shows, and at once on `PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED` and a zone change. A change redraws. The first signal that answers, in the table's order, puts the quest here.
- **Learned spots:** when an objective moves, the player's map and place are saved for that quest in `spots`, only while the option is on and only where the game gives a position, so not in instances. A spot counts only while the quest isn't done, since the turn-in is elsewhere. It goes when the quest leaves the log.
- **Switches:** "Signaler les quêtes de la zone" in the gear's menu and on the options page. Off, the check stops and nothing is here.
- **The Diagnostic panel** lists the quests here with the signal that answered, to learn which signals work on Forever.
- **Off, nothing is counted,** a quest with a usable item included: the separate mark for those was dropped, Ikar's ruling on 2026-11-08 (see [Markers](#markers)).

| Signal, best first | Gives | Evidence | Cost |
| --- | --- | --- | --- |
| `PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED`, `C_Minimap.IsInsideQuestBlob` | Exactly "inside the objective area" | Blizzard's item glow uses it. The client's tables hold areas for only 22 quests, though the server may supply more | None |
| `C_QuestLog.GetQuestsOnMap`, then distance to the player | The game's pin for the quest | Zmap and Wayfinder use it on Forever, Wayfinder for turn-ins. In-progress quests are untested | Test |
| `C_QuestLog.GetDistanceSqToQuest` | Distance | No installed addon uses it | Test |
| Learned spot: where an objective last progressed | This player's own spot, in any language, including new quests | Live. Only works after the first progress | Saved positions |
| Bundled objective table | 72% of vanilla quests get one place, and 94% of a tested set fall within 300 yards of the stated area. New quests: 39% have coordinates. See [quest-data-sources.md](quest-data-sources.md) | Measured | **GPL-3.0** |

Build the first four, and let the in-game probe show how often each one answers. Add the table only if they turn out too sparse, since it would bring back the licence. Distance signals use 300 yards. A one-second timer runs only while the feature is on.

### A glow on progress: optional, on by default

Ikar's ruling, 2026-11-06. When a quest's objective updates, its background glows once, for 0.7 seconds. If its group or a bar above it is closed, the closed header glows instead, so progress inside a closed group still shows. It comes from comparing objective counts on `QUEST_LOG_UPDATE`. Nothing moves, so it works in combat.

### Version 2: an organiser window

**Dropped, Ikar's ruling on 2026-11-07:** overblown, not really interesting. What it would have held:
- Multi-select to move several quests at once. Built in the tracker instead, with Ctrl+click, on 2026-11-08
- Export and import a layout as text, which also works as a backup
- Bulk share and bulk abandon, with a confirmation for abandon. Sharing came with the tracker's picking; abandon didn't, since the game asks about each quest on its own

### Maybe later

- Layout templates shared across characters
- A colour per group, without reusing difficulty colours
- A note per quest
- A setting that opens the current zone's group automatically
- Player-made rules for automatic placement
- Location as a suggestion or sort order, using [quest-data-sources.md](quest-data-sources.md)
- Highlighting a quest when you hover a mob for it. Questie saw `QuestObjective` lines with progress in unit tooltips out of combat

## Interaction

**Blizzard's click stays,** Ikar's decision: a plain click on a quest row opens its details on the map. Shift-click tracks the quest or stops tracking it, which moves it in or out of a group.

| Target | Input | Action |
| --- | --- | --- |
| Quest row, anywhere on its box | Any click, with chat open | Quest link, as Blizzard's tracker |
| Quest row | Left click | Open the quest's details on the map, as Blizzard's. On a complete auto-complete quest, opens the turn-in, as Blizzard's does |
| Quest row | Shift-click | Track, or stop tracking. Refused in combat |
| Quest row | Right click | Blizzard's menu plus Déplacer vers. In a group it has Blizzard's Arrêter le suivi, and out of one Suivre quête |
| Quest row | Hover | No tooltip, Ikar's rulings on 2026-11-10, asked why one showed: not the markers' names ("No tooltip, icons only"), nor in a party Blizzard's party progress ("Never on hover"), which Blizzard's own tracker shows. Blizzard's `OnQuestBlockHeader.OnEnter` still fires, saying no tooltip is up, so other addons can open theirs. Before the first group exists, one line says how to make one |
| Quest row, moved quest's grey line | Hover holding Shift or Ctrl | One plain word says what a click would then do, in the order a click tries them, Ikar's ruling on 2026-11-10 ("simpler, more subtle, no name, no color, just Suivre and Multiselection"): Suivre, or Blizzard's Arrêter le suivi (`OBJECTIVES_STOP_TRACKING`, as the right-click menu), Multisélection or Désélectionner (the menu's word), and Insérer le lien with chat open. White, in its own box drawn as a tooltip's (`TooltipBackdropTemplate`) at three quarters of a tooltip's size and half seen, Ikar's rulings later on 2026-11-10 ("twice smaller, and half transparent", then "let's try 75% size, opacity good"): beside the row, without the quest's name, or under the tooltip when one already says something (the line before the first group, a grey line's group). Grey in a fight, as a disabled button. It replaces the green `<Maj+clic pour ...>` lines of 2026-11-09. Pressing or letting go redraws it (`MODIFIER_STATE_CHANGED`); a Shift-click or a drag hides it |
| Quest row | Drag | Move or reorder |
| Quest row | Ctrl+click | Pick it, or unpick it, Ikar's request on 2026-11-08. A picked row shows its box at the hover's strength, washed gold with a gold left edge, as drop targets are lit. It moves nothing, so combat and the padlock allow it. Any click without Ctrl lets every pick go, then does what it always does. Only drawn rows stay picked: closing their group, a search or the quest leaving lets them go. Not saved |
| Picked row, with others picked | Drag | Carries every picked quest, dimmed, the copy showing how many. They land side by side in the order they show; dropped on one of their own rows, they gather there. An unpicked row still drags alone |
| Picked row, with others picked | Right click | "2 quêtes sélectionnées": Déplacer vers (each group, Nouveau groupe), Suivre ces quêtes for those in no group, Arrêter le suivi for those in one, Partager ces quêtes in a party, Désélectionner. No abandon: the game asks about each quest on its own. Moves refused in combat, as single ones |
| Moved quest's grey line | Left click, right click | As on the quest's row |
| Moved quest's grey line | Its button | Put the quest back in its section. Refused in combat |
| Map button | Click | Focus, as Blizzard's, which also tracks an untracked quest. **Focusing opens the quest's group and category,** the one case where something opens by itself |
| Share button | Click | Share the quest |
| Category bar | Left click | Open or close, with the standard sound |
| Category bar | Right click | Tout ouvrir, Tout fermer. On Suivi: Nouveau groupe |
| Suivi bar | Its + | Create a group, as Nouveau groupe. Refused while locked and in combat, because one stray click would move every row below it |
| Category bar inside Journal | Drag | Reorder. Suivi and Journal keep their places |
| Any group | Its eye | Open it and close every other group |
| Player's group | Left click | Open or close |
| Player's group | Right click | Renommer, Nouveau groupe, Fermer les autres, Supprimer le groupe |
| Player's group | Drag | Reorder |
| Automatic group | Left click, right click | Open or close. Menu: Fermer les autres |
| Tracker | Mouse wheel, scrollbar | Scroll |
| Title row | Search and filter buttons | Open the search box and the filter menu. Quiet until used, lit while active |
| Title row | Padlock | Lock or unlock. In combat, unlock until the fight ends. See [Combat](#combat) |
| Title row | Gear | A menu, as the quest log's own gear has, Ikar's ruling on 2026-11-06: after a group is deleted, "Annuler la suppression de « nom »" first (Ikar's ruling on 2026-11-08); then three switches, Suivi automatique de quête, Lueur lors d'une progression and Signaler les quêtes de la zone, then Options, which opens the addon's page in the game's options. It works while locked, since it changes nothing in the tracker. Refused in combat with `ERR_NOT_IN_COMBAT`, because the options panel can't open then |
| Title row | Pointer over the tracker | The title's buttons sit at half opacity at rest and come up to full while the pointer is over the tracker or its item buttons, Ikar's ruling on 2026-11-06. In game: `OnEnter` and `OnLeave` on the tracker's own frames, with a short delay before dimming so moving between rows doesn't flicker |

**Dragging:**
- The source row dims to 0.4 alpha, the value Blizzard uses on character select. A copy of the whole box follows the cursor, held where it was grabbed. A group or bar shows its name instead.
- A line shows where the row will land, using `ScrollBoxDragLineTemplate`. Other rows stay still until the drop.
- While a quest is dragged, each of the player's groups lights up as a target, header and rows together, and the one under the cursor lights up more, Ikar's ruling on 2026-11-06. The Suivi bar does the same, because dropping there starts a new group. Automatic groups don't light up, because a quest can't be dropped on them.
- Dropping on a player's header or in the gaps between its rows adds the quest at its end, even when it's collapsed. Dropping on the Suivi bar offers a new group.
- Dropping outside the player's groups cancels, and so does dropping a quest back on its own row, beside the tracker, or over the title where rows have scrolled away. Only the part of the list on screen takes a drop.
- A row fading out of the log can't be dragged or clicked.
- `OnUpdate` runs only during a drag.

**Finding the feature:** no chat message at login. Until the first group exists, hovering a quest row adds one instruction line to the tooltip.

**In-place rename rather than a popup:** it keeps the player's eyes on the row, and it avoids registering a popup for the most common edit.

## Combat

**A padlock is always on the title row,** Ikar's decision. It shows its state, Ikar's ruling on 2026-11-06: closed when locked, open when not. **The game's atlas tables have no open padlock in this style,** only closed ones (the level-up toast's `Levelup-Icon-Lock` is open, but has no closed twin), so `Communities-Icon-Lock` is drawn in two parts with `SetTexCoord`, cut at its body's top edge so no seam shows. **Unlocking swings the shackle open on its right leg,** 32°, Ikar's pick on 2026-11-08 among 10 proposals on the bench, which replaces the lifted half of 2026-11-06. **Locked, it's much brighter,** Ikar's ruling the same day: a third copy on top with `SetBlendMode("ADD")`, as the gear's. The swing uses `SetRotation` with a pivot, which needs an in-game test; without the atlas's data it stays one closed padlock, greyed while unlocked. While locked, bars, groups, their eyes, the Suivi bar's +, Tout ouvrir, Tout fermer, Fermer les autres and collapse-all change nothing, and a drag doesn't start. Each attempt flashes the padlock once, so the reason is visible. Scrolling, opening a quest's details and the menu's Déplacer vers still work. Out of combat, clicking it locks or unlocks, and that choice is saved.

**Combat locks it for the length of the fight,** whatever the player chose. Clicking it unlocks the tracker until combat ends, and the next fight locks again. When combat ends, the tracker goes back to the player's own choice. In combat, scrolling is locked too, unless unlocked, because it moves rows away from their item buttons.

A closed group stays closed, so its quest items can't be reached until it's opened. That's what closed means, not a defect.

| In combat | Locked | Unlocked |
| --- | --- | --- |
| Objective text and progress | Keep updating in place | Same |
| Open, close, scroll | No | Yes |
| Item buttons on screen | Work | Work, but stay where they were. See below |
| Item of a quest opened during the fight | Not applicable | A grey icon that does nothing. The real button replaces it when combat ends |
| Drag, move, reorder, create or delete a group, filter, search | Refused with Blizzard's `ERR_NOT_IN_COMBAT` message. A drag in progress is cancelled | Same |
| A quest accepted, finished or focused | Row changes wait until combat ends. Built with the item buttons, since it only keeps them lined up. Until then rows change in combat, and a focus follows the padlock, as in [Quest lifecycle](#quest-lifecycle) | Same |
| Opening quest details | The panel can't open, so the click explains that instead of failing silently | Same |

**Why item buttons can't follow their rows in combat.** Questie and both Kaliel's forks use a secure button to use a quest item. Addon code can't show, hide, move or reparent one in combat: `Show`, `Hide`, `SetPoint` and `SetParent` all carry `IsProtectedFunction`. Whatever it's parented or anchored to inherits the limit, so a button inside a row would stop that row moving, and the lock could never be released.

So item buttons sit on `UIParent`, placed over their row by position after each layout and scroll step, and never anchored to it. Rows stay ordinary frames that can open, close and scroll in combat. Kaliel's Mists fork separates them the same way: its secure buttons are on a bar under `UIParent`, and its wheel scrolling has no combat check.

**What that means in an unlocked fight:** a button above the change stays lined up. A button whose row moved stays where it was, still works, and dims, because `SetAlpha` isn't restricted. It can't be hidden or made unclickable, because `Hide` and `EnableMouse` are. Everything lines up again when combat ends.

**If a plain button can use the item, none of this is needed.** Blizzard's own button is plain and calls `UseQuestLogSpecialItem`, and its tracker never checks for combat. That function isn't in the API docs, and I expect it to be blocked for addons, but the first in-game test should try it.

Rejected: a separate bar of item buttons, as in Kaliel's Mists. It avoids misplaced buttons, but takes items out of their quests' rows and makes them reachable from closed groups, which isn't what's wanted.

## Options

Ikar's ruling, 2026-11-06: text size, width and height are options in the addon, and the game's Edit Mode keeps working for position, if possible. It is possible, because `ObjectiveTrackerFrame` stays as the host.

**A zoom in place of the text size,** Ikar's ruling on 2026-11-10. Ikar found the addon's text size wouldn't go past 11, and at 8 the headers shrank but kept their spacing ("doesn't feel very adaptable. Maybe easier to have a global zoom level?"); offered a zoom, Ikar took "Zoom replaces Taille du texte". Why it stopped at 11: sizes 8 to 11 were set on the rows' font directly, 12 to 20 by pointing it at Blizzard's `ObjectiveTrackerFont<size>` families, and in game a size set directly stayed through those later changes. That's inferred from what Ikar saw; the offline fake now behaves that way. The rows' fonts are now only ever pointed at Blizzard's tracker fonts, which Edit Mode's text size sets.

| Option | Where | Range | Default | How it works |
| --- | --- | --- | --- | --- |
| Position | Edit Mode | | Blizzard's | The host stays the Edit Mode system, so dragging, snapping, layouts and "reset position" all work. The rows follow it |
| Opacity | Edit Mode | 0 to 100 | 0 | Blizzard's setting on the host, as in [tracker-parity.md](tracker-parity.md) F5 |
| Zoom | Addon options, first in Apparence | 50 to 200 % | 100 % | `SetScale` on the rows' frame, so text, bars, icons, gaps and width grow together, crisp at any size. The height set stays the height on screen. The host is the zoomed width plus the zoomed scrollbar room, so Edit Mode's box fits; the "Temps" panel, popups and item buttons follow. The click word's box doesn't, as a tooltip doesn't |
| Text size | Edit Mode | 12 to 20 | 12 | The rows' fonts follow Blizzard's tracker fonts, as Blizzard's rows do. Until 2026-11-10 also in the addon, 8 to 20, the last change winning |
| Height | Addon options, and Edit Mode once the tracker has been moved | 200 to 1000 | 530, given once at install | Whichever was changed last wins |
| Width | Addon options | 220 to 400 | 310 | The rows' width. The host is set to that width plus the scrollbar's 12 |
| Quest background opacity | Addon options | 0 to 100, for rest, combat, and hover or clicked | 15, 15 and 40 | One texture per row, with `SetAlpha` |
| Whole tracker opacity | Addon options | 0 to 100, in and out of combat | 90 out of combat, 50 in | `SetAlpha` on the rows' parent and on the item buttons' layer, which isn't its child |
| Header saturation | Addon options | 0 to 100 | 50 | `SetDesaturation` on the art, a calculated colour for the text |
| Share button only on hover | Addon options | On or off | On | The button stays hidden until the row is hovered |
| Group search button | Addon options | On or off | Off | With it off, rows draw no find-group eye, [tracker-parity.md](tracker-parity.md) G1 to G4 |
| Area highlight | Addon options and the gear's menu | On or off | On | See [Area highlight](#area-highlight-optional-on-by-default) |
| Glow on progress | Addon options | On or off | On | See [A glow on progress](#a-glow-on-progress-optional-on-by-default) |
| Markers | Addon options | Icons, Text or None | Icons | See [Markers](#markers) |
| Markers shown | Addon options, their own section | On or off, for each marker | All on | See [Markers](#markers) |
| Auto-tracking | Addon options | On or off | Off, Ikar's ruling on 2026-11-06 | The game's `autoQuestWatch`, with the game's own label and tooltip, `AUTO_QUEST_WATCH_TEXT` "Suivi automatique de quête" and `OPTION_TOOLTIP_AUTO_QUEST_WATCH`. See below |
| Advanced: under the title, group indent, quest indent, above a group, between bars, marker size | Addon options, advanced section | The test bench's ranges | −4, 0, 40, 5, 5 and 13 | Layout values, with a reset |

**The defaults are Ikar's, 2026-11-07,** set on the test bench, in `DB.DEFAULTS`. A saved value already there stays, so in game Ikar presses the page's Defaults button once to take them.

**Tips page, Ikar's request on 2026-11-08, tested offline only.** A small tutorial on the shortcuts and the mechanics that don't show at first glance. My calls:
- It is a subpage, "Astuces", under the addon's in the options list, laid out as Blizzard's own pages: a title, a divider, two headings (Raccourcis, À savoir), then a gold label and its text on each line.
- A button row, "Astuces / Afficher", opens it from the top of the addon's page. Like the page itself, it is refused in combat.
- Shortcuts: click, Shift+click, Ctrl+click, right-click, drag, and the four key bindings. Those start unbound, and the text says where to bind them, built from the game's own strings (`SETTINGS_TITLE`, `SETTINGS_KEYBINDINGS_LABEL`, `ADDONS`), so it reads "Options > Raccourcis clavier > Add-ons".
- Rules: what Suivi means, the padlock and combat, the grey line in the Journal, what the gear holds (including undo), "Hors liste", and the white arrow.
- The text lives in `Locale.lua` (`TIPS`, French and English). The bench shows the same French text, folded, at the top of "Edit Mode and game options".

`SetAlpha` isn't protected, so both opacities can change in combat. An invisible row or item button still takes clicks, though, and turning that off for an item button isn't allowed in combat. So a tracker at opacity 0 in combat would have invisible buttons that still work, which needs testing and may mean a minimum above 0.

**What Edit Mode can't do, from `EditModeSettingDisplayInfo.lua` and `EditModeObjectiveTrackerSystemMixin`:**
- Its dialog for the tracker has height 400 to 1000, opacity and text size 12 to 20.
- Height only appears once the tracker is moved. At the default position, height follows the screen, so the addon's option is the only control there.
- It has no width. Its rows come from Blizzard's own table, and adding one means writing to that table, which risks taint. So width stays in the addon's panel.
- It has no official way to add a system. `LibEditMode` exists for addons with frames of their own, and this addon doesn't need it, because the host is already a system.

**Width and the scrollbar's room.** `ObjectiveTrackerFrame:SetWidth(width + 12)` sets the host, with the rows at its left and the scrollbar in the 12 on its right. In Blizzard's source, neither the host's container nor the managed frame system reads or sets its width, so this looks safe, and Edit Mode's selection box should then fit the panel. The panel keeps its right edge and grows left at the default position. Away from it, it grows away from the nearer edge of the screen. If `SetWidth` causes trouble, the fallback is to leave the host at 260 and anchor the rows to its top right, at the cost of a selection box that doesn't match.

**The tracker background's edges,** Ikar's ruling on 2026-11-06. Blizzard's XML starts it 30 left of the host and ends it 5 past the right, which leaves 50 empty units left of the quest text when map buttons are off. Here it starts 5 left of the rows, with `NineSlice:SetPoint("TOPLEFT", -5, 0)`. The right anchor stays as it is, because the host is 12 wider than the rows, which puts it past the scrollbar. On the test bench, no row content passes that left edge at text 12, 16 or 20 (8, 12 and 20 until the addon's own text size went on 2026-11-10), with map buttons on or off, because the indent grows to make room. Only art with its own backing goes further: the bars, Blizzard's rewards toast ([tracker-parity.md](tracker-parity.md) BT1), a scenario's final-stage background if scenarios exist here, tooltips and menus. Popups stay inside because they're centred, where Blizzard's start 20 left of the host.

**Height, "last changed wins".** The addon saves a value only when it's changed in its own panel. The post-hook on the host's size compares Edit Mode's value with the one it last saw, and on a change clears the saved value. That way neither slider ever looks dead, and a layout switch in Edit Mode still applies. Rows use the addon's own font objects, pointed at Blizzard's and never sized directly, so nothing is written to Blizzard's.

**Where the panel lives:** Blizzard's Settings, under Options > AddOns, with the addon compartment, a slash command and the gear on the title row leading to it. The gear is Ikar's ruling on 2026-11-06, and uses `questlog-icon-setting`, the quest log's own settings button from `UIPanelIconDropdownButtonTemplate`, at its 15 by 16. **It's bright when it can be used,** Ikar's ruling on 2026-11-06: the game has no bright version, as it has no open padlock, so a second copy sits on top with `SetBlendMode("ADD")`, the way the template draws its own highlight. In combat it's greyed with `SetDesaturated(true)` and half opacity, without the copy. It applies changes immediately and has a reset. The other options listed elsewhere in this plan go in it too.

**A reset per section,** Ikar's request on 2026-11-09, tested offline only. Each section with settings ends with a row, "Valeurs par défaut", whose button, "Réinitialiser" (the game's `RESET`), puts back that section's settings and no other's: the first block under the page's title, Apparence, Marqueurs affichés and Avancé. It's the row Blizzard ends its chat settings with, "Réinitialiser la position de la discussion". The panel's own "Par défaut" button still resets the whole page. **My calls:**
- No confirmation, as Blizzard's reset rows don't ask; only the panel's "Par défaut" does.
- Only settings off their default change. The tracker switch, already on, would otherwise bring KaLi Quest's tracker back over a section only Blizzard's shows.
- Height goes to 530, fixed, as the page's "Par défaut" does, rather than back to following Edit Mode, and the zoom to 100 %.
- The rows don't show in the panel's search, where four "Valeurs par défaut" would say nothing.

**Reporting a bug,** Ikar's request on 2026-11-09, tested offline only. An addon can't send anything out of the game: no network, no clipboard (`CopyToClipboard` is Blizzard's only), only its saved file. So the player copies a report and pastes it where we read it.
- **The window,** "Signaler un bug", in `UI/Report.lua`, opens from the gear menu's last line, a row of the options page's Diagnostic section, the Diagnostic panel's "Copier le rapport" and `/kq report`. It holds a short text, the address to paste at, one button, "Copier le rapport", and the report itself, read-only, made again each time it opens. The button selects the whole report and says "Ctrl+C pour copier"; once copied, the box lets go of the keyboard and says to paste it. Built on `DefaultPanelFlatTemplate`, Blizzard's flat panel.
- **The address is to be defined later,** Ikar's words: `Report.URL` in `UI/Report.lua`. Until it's set, the line says "à venir"; once set, it shows in a box the player can copy. Ikar's answer on 2026-11-09: none for now, as they test locally before publishing anywhere. **Ikar's ruling later on 2026-11-09:** the addon is on GitHub, public, as `Ikar-Rahl/Wow-KaLi-Quest`, and the address is its new-issue page.
- **The report** is plain text, in parts that each fail on their own: status (versions, build, language, saved data, class, level, faction, map, screen), the API check, every error with its stack, what the game blocked or warned about, the Diagnostic panel's lines, every option, the groups and their quests, the tree, the other addons loaded with their versions, the last `/kq test` in game, and the debug log's last 100 lines. It holds no character, realm or guild name. It stops at 60,000 characters, under GitHub's 65,536 for an issue, losing the log first.
- **The API check,** `Shared/SelfCheck.lua` with KaLi Quest's assumptions in `Core/SelfCheck.lua`, looks for everything the addon takes from the game: about 200 functions, tables and fonts, 37 events, 35 atlases, 14 templates and 3 CVars. The list, `Data/Needs.lua`, is made from the code by `quest/tools/run_tests.py --write-needs`, and the offline run fails while it's out of date, so it can't go stale. It runs at each login, kept per build in `KaLiQuestDevDB.apiChecks`, and again for each report, which names what's missing and what changed since the last other build seen: what a patch broke. A name one of Blizzard's own addons defines is only looked for once that addon has loaded. It changes nothing and says nothing in chat: the Diagnostic panel has one line for it.
- **What the addon assumes of the game's answers is tried there too,** Ikar's ruling on 2026-11-09: every assumption about the game must be covered by a test, and only one run against the real game can catch a wrong one, as the offline tests run on a fake game written to the same assumption. First, the quest log's headers (`SelfCheck.Headers`): each has a `headerSortKey` of an area or a `QuestSort`, the area's name from `C_Map.GetAreaInfo` or the `QuestSort` name is the header's own, a class header carries its class's ID with no name table, and the key places it as its name does on a French or English client. Since later that day, the rest of [Assumptions about the game](#assumptions-about-the-game) that code can see, seven checks in all. They run once the log has loaded after login, into the build's entry, at each zone change, and in each report, which lists each check with what didn't hold. The Diagnostic panel's API line counts what doesn't hold. When something doesn't hold, or the game lacks a name other than a string, a line in chat says so once per build and addon version and points to `/kq report` (see below).
- **What the game reports against the addon** is kept too, the last 20 in `KaLiQuestDevDB.gameWarnings`: an action it blocked or forbade (`ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`) and a Lua warning naming one of its files (`LUA_WARNING`).

**My calls in the bug report:**
- Answering Ikar's question: the API check runs at login and again for each report. The unit tests don't run there: they test the addon's own logic on a fake game, so they'd say the same on every computer, and they're checked before each release.
- The Diagnostic panel's "Copier le rapport" opens this window rather than a report of its own, so there's one report.
- What the check finds missing is only reported, never acted on: no feature turns itself off, and no chat line at login.

**Auto-tracking, off at install,** Ikar's ruling on 2026-11-06. Forever's own options have no checkbox for `autoQuestWatch`: only Blizzard's code reads it, so the addon's panel becomes the only place to change it short of `/console`. The choice is saved per character and applied with `SetCVar` at `PLAYER_LOGIN`, and again at `VARIABLES_LOADED` when that comes later, because the game's own copy can arrive then and overwrite it. So it holds whether the game keeps the value per account or per character. Once the game's copy has arrived, a change made outside the addon, with `/console` or by another addon, becomes the choice, so the two never fight. My call, confirmed by Ikar on 2026-11-08: the value found on the first run is saved too and put back at `PLAYER_LOGOUT`. If the game's copy arrives after login and differs from what the addon set, that copy is the one saved. Without this, a player who removes the addon would find new quests no longer tracked and no option to fix it.

## Saved data

```lua
-- Declared with ## SavedVariablesPerCharacter. The name follows Ikar's working name, KaLi Quest, and is permanent from the first release
KaLiQuestCharDB = {
    version = 1,
    nextGroupID = 3,
    locked = false,            -- the padlock, out of combat
    groups = {                 -- the player's groups, in display order
        { id = 1, name = "À faire maintenant", quests = { 60, 7, 62 } },
        { id = 2, name = "À faire plus tard", quests = { 40 } },
    },
    categoryOrder = nil,       -- nil means the default order
    open = {                   -- absent means collapsed, so only what's open is stored
        tracker = true,        -- the title's collapse-all, inverted because it starts open
        categories = { instances = true },
        groups = { [1] = true },
        headers = { ["Les Mortemines"] = true },
    },
    filters = {},              -- by ID, such as { tag = { [81] = true } }. Search text isn't saved
    disabledExtensions = {},   -- other addons' widgets and markers the player turned off, by their ID
    spots = {},                -- only with the area highlight on: [questID] = { mapID, x, y }, where an objective last moved
    options = { autoQuestWatch = false, progressFlash = true, areaHighlight = true },
    autoQuestWatchOriginal = "1", -- the game's own value found on the first run, put back at logout
    repeatable = { [7] = true }, -- quests seen repeating while in the log, since out of it the game may not know
}
```

Debug data is account-wide, in `KaLiQuestDevDB`: the debug switches, a log of up to 3,000 lines kept only while debug mode is on, every error counted by message, and the last in-game test run.

Rules that protect the player's work:
- A quest is in at most one group. `Move` enforces this, and loading repairs duplicates by keeping the first.
- IDs for quests no longer in the log are ignored when drawing, and are never deleted because the log looks empty. The log can read as empty during login.
- Only a confirmed turn-in of a non-repeatable quest removes its ID. A quest that leaves the log with no turn-in, abandoned, leaves its group at once, Ikar's ruling on 2026-11-09, so accepted again it lands in Journal; before, it kept its place. Either event can come first, so the check waits a second for a turn-in. A repeatable quest turned in keeps its place. The game dropping its watch doesn't count as stopping tracking when the quest has left the log.
- A login clean-up removes IDs where `C_QuestLog.IsQuestFlaggedCompleted` is true and the quest isn't repeatable. Whether it repeats comes first from `repeatable`, filled from the log's `frequency` while the quest is in it, because `IsRepeatableQuest` may not know a quest that has left the log, and a daily done today is flagged completed until the reset.
- Loading works on a copy, defaults and repairs included, so an error part-way leaves the saved table as it was.
- Group names are the player's own text. Everything else uses IDs. `open.headers` saves a header under its `headerSortKey`, as Blizzard's quest map does, and under its text only when it has none. Text saved before 2026-11-09 still opens its header until the header is opened or closed again, which saves the key instead.

### Surviving launches and updates

| Situation | What protects the layout |
| --- | --- |
| Client restart | The client's saved-variables file. The addon first touches the variable in its own `ADDON_LOADED`, because anything written while its files load is replaced when the saved data is restored. Researched in [persistence-research.md](persistence-research.md) |
| Addon update | The saved file is separate from the addon's code. The addon's folder name and the variable's name stay fixed from the first release, because changing either leaves the saved layout behind |
| A new data format | `version` goes up one step at a time, and each step keeps fields it doesn't know. A step works on a copy, which replaces the original only if the step succeeds. A failed step changes nothing, and the addon falls back to Blizzard's tracker |
| An older addon reading newer data | It leaves the table untouched and falls back to Blizzard's tracker |
| Game patch | Quests are stored by ID, and IDs missing from the log are ignored rather than deleted. If a patch stops the addon loading, its file should stay as it is. Test that by logging in once with the addon disabled |

Layouts stay in per-character files rather than one account-wide table. If a restore ever fails and the empty state is written back, only one character's layout is lost.

Limits, from general WoW behaviour and not tested on this client:
- The client writes the file only at logout, exit or `/reload`, so a game crash loses changes made since the last one.
- Renaming a character or moving realm changes the per-character file's folder. Nothing covers that since the organiser window, with its export and import, was dropped.

## Quest lifecycle

| Event | Action |
| --- | --- |
| `QUEST_DETAIL`, `QUEST_COMPLETE` | Remember the NPC from `UnitGUID("questnpc")`, for the quest `GetQuestID()` shows. A secret GUID counts as none |
| `QUEST_TURNED_IN` | Remember the quest's group, slot, NPC and time. Remove it unless it's repeatable. Blizzard's turn-in animation shows the row should leave gently |
| `QUEST_ACCEPTED` | The placement order under [Management features](#management-features) |
| `QUEST_REMOVED` | Stop drawing it, keep the placement |
| `QUEST_LOG_UPDATE` | Refresh, coalesced to the next frame, and compare objective counts for the glow on progress |
| `QUEST_WATCH_LIST_CHANGED` | On the next frame, read where the list ended up and follow it. See [Tracked means in a group](#tracked-means-in-a-group) |
| `SUPER_TRACKING_CHANGED` | Open the focused quest's group and category, or once unlocked if the tracker is locked |
| `GROUP_ROSTER_UPDATE`, `UNIT_QUEST_LOG_CHANGED` | Refresh party counts and share buttons |
| `ZONE_CHANGED_NEW_AREA` | Reorder Monde's zone headers only, never the player's groups |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` | Lock, then return to the player's own lock setting, apply what's waiting and line up the item buttons |
| `PLAYER_LOGIN`, `PLAYER_LOGOUT` | Apply this character's auto-tracking choice, then put the game's own value back. See [Options](#options) |

The 2-minute same-NPC rule is a heuristic, and hub NPCs will sometimes give an unrelated quest. The cost is one easy move. QuestieDB has real chain data, but it would bring back a bundled GPL-3.0 table.

## Why the whole tracker is rewritten

Ikar's decision, 2026-11-06, replacing the earlier plan to rewrite only the quest section.

The tree, dragging, reordering, filters and search all need rows the addon owns. QuestSections Forever shows the cost of the alternative: it moves Blizzard's blocks after every layout, so it needs retry timers and a repair step for blocks left invisible, and it calls `MarkDirty`, which risks taint.

The addon draws everything, using Blizzard's templates, fonts, colours and spacing. `ObjectiveTrackerFrame` stays as an invisible host, because Edit Mode, the timer panel and other addons depend on it, and Blizzard's sections keep running hidden, because other Blizzard code calls them directly. Nothing is written into Blizzard's Lua tables. [tracker-parity.md](tracker-parity.md) has the method, the alternatives and every feature. If the in-game test fails, the fallback is Questie's full hide with a home-made timer panel.

## What this removes

No bundled location table is needed, so **GPL-3.0 is no longer forced on the addon.** The licence is **MIT**, Ikar's ruling on 2026-11-07, in `quest/addon/KaLiQuest/LICENSE`. The location research stays available for the optional features above.

## Assumptions about the game

**Ikar's ruling on 2026-11-09: every assumption about the game must be covered by a test.** The offline tests and `/kq test` run on a fake game written to the same assumptions, so they test the addon's logic, not the game. What the game does is tested where it can be: in game by the API check (`Core/SelfCheck.lua`), on every player's client, at login once the log has loaded, at each zone change and in each bug report; offline against the game's own tables in `reference/db2` and Blizzard's source; and, where no code can see it, by a test in game with what to expect. Inventory of 2026-11-09:

| What the addon assumes | Where it counts | Test |
| --- | --- | --- |
| Every name it calls exists: functions, tables, fonts, events, atlases, templates, CVars and the game strings it shows | Everywhere | API check, from `Data/Needs.lua`, which the offline run keeps current |
| A log header's `headerSortKey` is 0x40000000 plus its area or 0x20000000 plus its `QuestSort`, and that ID names the header | `Categories`, `open.headers` | API check "log headers" (risk 7) |
| A class header carries its class's `QuestSort` ID | `Categories.CLASS_SORT` | API check "log headers"; offline against `QuestSort`'s English names |
| `C_QuestLog.GetInfo` lists every quest, even under a header collapsed in the game's log | `QuestLog.Read` | API check "log listing" (risk 8), which says how many headers were collapsed |
| `GetZoneText()` is the name of the area your map shows, so the text of that zone's header | Monde's first zone, the filter's "Zone actuelle" | API check "zone name", every zone visited, through `Data/Maps.lua` made from the game's `UiMapAssignment`. Darkshore's map is named "Sombrivage" but its area "Sombrivage (Darkshore)", the header's text |
| The quest tags, frequencies, classifications and difficulties are the numbers the filter reads | `Filter.TAG`, `Filter.FREQUENCY`, `Filter.QUESTLINE`, `Filter.DIFFICULTY`, `Filter.CLASSIFICATION` | API check "game numbers" against the game's enums and constants; offline, the tags against `QuestInfo`. Tag 21 is named "Life" there, while Questie calls it Class: the filter shows the game's own name for it and assumes nothing of its meaning |
| The game tracks 25 quests at most, and `AddQuestWatch` refuses only past them | `Model`, the off-list marker | API check "game numbers" (`MAX_QUEST_WATCHES`) and "tracking limit", which notes each refusal (risk 4) |
| An addon can set `autoQuestWatch` | Auto-tracking | API check "settings" (risk 4) |
| Shift is the key for tracking and for links | The tips and the click hints | API check "settings", with `GetModifiedClick` |
| Blizzard's tracker and its sections, and the addon's own frames, aren't protected | Parking, the tracker in a fight | API check "frames" (risks 1 and 3) |
| The quest giver answers to `UnitGUID("questnpc")` at `QUEST_DETAIL` and `QUEST_COMPLETE`, as does `GetQuestID()` | The follow-up rule | Probe (risk 18). In game: a follow-up keeps its place, Ikar confirmed on 2026-11-07 |
| `QUEST_TURNED_IN` comes within a second of `QUEST_REMOVED`, in either order | An abandoned quest leaving its group | Probe (risk 18: 0.5 s and 0.1 s). In game: abandoning a quest in a group |
| A secure item button acts on the key press unless `useOnKeyDown` is false | Quest item buttons | Blizzard's `SecureTemplates.lua`. In game: a quest item click |
| Other addons hook `QuestObjectiveTracker.AddBlock` and `OnQuestBlockHeader.OnEnter` | Rows | Probe (risk 6). In game: Spoken plays, Ikar confirmed on 2026-11-06 |
| Forever Quest Tint marks a row by its exact title | The rows' hidden title copy | In game: the ∞ on a tracked quest, Ikar confirmed on 2026-11-09 |
| The game's location signals mean what they say: blob, pins, distance | The area highlight | Probe (risk 12). No automatic test: the game gives nothing to hold them against |
| Saved data survives a full restart | Saved data | In game, Ikar confirmed on 2026-11-06 (risk 9) |

**Ikar's ruling on 2026-11-09: when something isn't as assumed, a chat message is enough.** Once per game build and addon version, a line in chat says the game doesn't answer quite as the addon expects, so some of what it shows may be wrong, and to type `/kq report`. The first check that fails says it: once the log has loaded after login, at a zone change, or at a refused tracking. A missing game string alone isn't said, as the addon has its own wording for each. Nothing else changes: no fallback, such as taking the zone's name from the map's area.

Not assumptions, because the code works either way: when Blizzard sets up its tracker (sections are parked whenever it adds them), whether it hides an empty host (a stand-in places the rows), frame levels in Blizzard's templates (the windows' X goes above every part), whether Forever loads the group finder (looked for at run time), and the order the game sorts its log in (Monde sorts its own zones since 2026-11-09).

## Risks to test in-game

1. **Parking Blizzard's contents under a kept host.** Whether the host or sections are protected, and whether anything brings them back. Test this first, because the fallback changes the plan. See [tracker-parity.md](tracker-parity.md). **First run, 2026-11-06: promising.** Nothing is protected, every section and the header reparented without error, nothing brought them back in 60 seconds that included a fight, the host stayed shown, and `SetWidth(271)` held (read back as 272). The host's `Update` hook never ran in that minute, so a longer run with quest progress is still needed. That run parked by hand long after login; parking at login is undone by Blizzard's own setup, see Build order step 3.
2. **Keeping the host shown with nothing tracked.** Blizzard's `Update` hides it when its sections are empty, but the addon's rows no longer depend on the tracked list. Re-show it from an `OnHide` hook, or anchor the root to it from `UIParent`, which would lose the fading that other addons apply.
3. **Rows staying free in combat.** With item buttons on `UIParent`, whether `IsProtected()` stays false on rows and the scroll frame, and whether unlocked opening, closing and scrolling run with no blocked message.
4. **Groups and the game's tracked list.** Whether one frame is enough to see through DialogueUI's flips, whether several changes in one frame arrive as one `UniqueEvent`, what `AddQuestWatch` does at 25 (`/kqprobe watch` covers both), whether a login with a stale list keeps the player's groups, and what untracking does to a quest's map pin, minimap area and `IsInsideQuestBlob`. The client's own code isn't visible, so only this settles the last one. Also whether `SetCVar("autoQuestWatch")` is allowed, since `SetCVar` refuses secure CVars, whether the game keeps it per account or per character, whether the server's copy arrives after `PLAYER_LOGIN` and overwrites it (the probe's cvars section keeps a timeline), and whether a value set at `PLAYER_LOGOUT` is kept. **First run:** `autoQuestWatch` is stored on the server for the whole account, not secure, and `SetCVar` works on it. The value put back at logout was there at the next login. Watch-list events at login and after a zone change carry no quest ID. A turn-in fires the quest's watch removal in the same frame as `QUEST_REMOVED`. **Second run:** three `AddQuestWatch` calls in one frame fired three `QUEST_WATCH_LIST_CHANGED` events, each with its quest ID and `true`, and three removals fired three with `false`, so this build doesn't merge them. The addon compares the whole list anyway. `AddQuestWatch` at 25 and the map pin are still untested.
5. **Which sections can fill on Forever.** `C_Scenario.GetInfo`, `GetTasksTable`, `GetObjectiveTrackerWidgetSetID`, `GetCollectableSourceTrackingEnabled`, `GetTrackedPerksActivities`, and whether achievements and recipes can be tracked.
6. **Firing `AddBlock` hooks for the addon's rows.** Whether Spoken's button appears, works and rebinds. See [addon-extensions.md](addon-extensions.md). **First run: it appears.** A 14×14 button was added to the test row within half a second, and `QuestObjectiveTracker.AddBlock` is hooked securely, with no taint. **It plays,** Ikar confirmed on 2026-11-06. Rebinding when a row shows another quest is still untested.
7. **The log's headers.** Print every header with `headerSortKey`, to see whether it holds a usable ID, and whether class, profession and instance headers read as `QuestSort` and `AreaTable` say in French. **First run: likely an ID.** "Dun Morogh" has `headerSortKey` 1073741825, which is 0x40000000 plus 1, Dun Morogh's `AreaTable` ID. A class, profession or event header is needed to see how `QuestSort` headers are encoded; if they are too, headers can be classified by ID in any language. **Probe log of 2026-11-09:** "Hurlevent" 1073743343 (0x40000000 + 1519), "Sombrivage (Darkshore)" 1073741972 (+ 148) and "La salle des Thanes" 1073758743 (+ 16919) are `AreaTable` IDs, and "Campement" 536871578 is 0x20000000 + 666, the `QuestSort` Camping. So `QuestSort` headers carry their ID too; no class or profession header has been seen yet. **Since 2026-11-09 the addon classifies headers and saves `open.headers` by this key,** and by the text only for a key of another shape. Still to see: a class and a profession header, to confirm their keys. Since the same day the API check tries this on the player's own log at each login and in each report (see "Reporting a bug").
8. **Listing all quests.** Whether `C_QuestLog.GetInfo` lists quests under a header collapsed in the native log, as `QuestMapFrame.lua` implies. `/kqprobe collapse` collapses one, counts, and opens it again. **First run: very likely yes.** Collapsing "Dun Morogh" left 10 entries and 9 quest rows, right away and half a second later. The probe didn't read the header's own state back, so a collapse that did nothing isn't ruled out yet; it now records it.
9. **Saving across a full restart, with the addon's own data.** The beta bug is fixed and AutoBiographer keeps its data here, so this is an ordinary acceptance test. Only a full exit and restart counts. Also log in once with the addon disabled. **First run, 2026-11-06: it holds.** After Ikar quit the game and started it again, the layout came back whole (Quêtes: #318, #99162, #412), and auto-tracking was set at login and put back at logout. At that login the quest log read as empty, with nothing tracked, 5 seconds after `PLAYER_LOGIN`, which is why reconciliation waits for a log with quests in it. Still to do: one login with the addon disabled.
10. **Quest tags and classifications.** Whether `GetQuestTagInfo` is right on Forever for the quests Questie corrects, whether tag 21 marks class quests, and what `GetQuestClassification` returns. See [quest-properties.md](quest-properties.md).
11. **Search text.** What `CaseAccentInsensitiveParse` does with French, and whether `GetQuestLogQuestText` answers for every quest in the log.
12. **Location signals for the highlight.** What `GetQuestsOnMap`, `GetDistanceSqToQuest` and the quest area event return for quests in progress.
13. **Next step text.** Whether `GetNextWaypointText` returns anything on Forever.
14. **Item buttons.** First, a plain button calling `UseQuestLogSpecialItem`, in and out of combat. If it isn't blocked, the combat limits on items disappear. Otherwise a secure button with range, charges and cooldown, tried with physical clicks in and out of combat, and whether it follows the host's fading and hiding, since it isn't the host's child.
15. **Clicks from addon code.** `QuestLogPushQuest`, `QuestMapFrame_OpenToQuestDetails`, `ShowQuestComplete`, `ShowQuestOffer`, `C_SuperTrack` and the gear's `Settings.OpenToCategory`, in and out of combat.
16. **Marker and share art.** Whether each icon exists on this client, with `C_Texture.GetAtlasInfo`, and stays readable small. Also which of the two art sets the tracker's atlases resolve to: the default gold one, or Forever's `c60` bronze one, which is `UiTextureAtlasSetID` 1.
17. **`Menu.ModifyMenu` on the log.** Whether `owner.questID` is available in `MENU_QUEST_MAP_LOG_TITLE`. Blizzard sometimes passes another parent as the menu's owner. **First run: yes.** A right-click on "Un froid dangereux" in the map's log gave `owner.questID` 99162. `contextData` was empty.
18. **`UnitGUID("questnpc")` at turn-in and accept time.** Blizzard's quest frame uses that unit token, but not with `UnitGUID`. **First run: only while the frame is open.** It gives the NPC at `QUEST_PROGRESS`, `QUEST_COMPLETE` and `QUEST_DETAIL`, and nil at `QUEST_TURNED_IN` and `QUEST_ACCEPTED`, which come after the frame closes. So the addon takes it at `QUEST_COMPLETE` and `QUEST_DETAIL`, keyed by `GetQuestID()`, which the next run checks. The turn-in also arrived about half a second after `QUEST_REMOVED`, so the quest has left the log by then. **Second run:** `QUEST_COMPLETE` gave both the NPC and `GetQuestID()` for #99161. This time `QUEST_TURNED_IN` came 0.1 s before `QUEST_REMOVED`, so the order varies. The addon handles both orders: the turn-in drops the quest from its group, and a dropped watch on a quest that has left the log is ignored. #99161 left Ikar's Quêtes group as it should. A follow-up from the same NPC is still untested.
19. **Taint** from the delete confirmation popup and the hooks, checked with `/console taintLog 1` after combat, quest items (click, shift-click), Edit Mode, popups, the find-group eye and the map button on rows. The find-group check calls `C_LFGList.CanCreateQuestGroup` directly: `QuestUtil.CanCreateQuestGroup` caches its answer in a table of Blizzard's, which a call from the addon would taint for Blizzard's own tracker.
20. **Longest French strings** at text size 20, on group names, dungeon names, filter labels and menus.
21. **Host width.** Whether `ObjectiveTrackerFrame:SetWidth` stays set through Edit Mode, layout switches and reloads, with no taint, and whether Edit Mode's selection box and the right-side stacking follow it.

## Build order

Started on 2026-11-06, Ikar's go-ahead, under Ikar's working name **KaLi Quest** (folder `KaLiQuest`, slash command `/kq`). The code is in `quest/addon/` and linked into the game's `Interface\AddOns` with junctions by `tools/link_addons.cmd`. How to test it is in the repository's [README](../../README.md). The look and behaviour are still polished first in [the test bench](../bench/README.md).

**In the family's repository, 2026-11-11.** At Ikar's request, KaLi Quest and KaLi Recipe share one public repository, [Ikar-Rahl/Warcraft-KaLi](https://github.com/Ikar-Rahl/Warcraft-KaLi), with this addon's history: `addon/` became `quest/addon/`, `docs/` `quest/docs/`, `testbench/` `quest/bench/`, and `tools/scripts/` `quest/tools/` (the location research in `quest/tools/research/`). The probe, kept out of git so it wouldn't ship, is in it now: players install the addon's own folder only, and a release package, once there is one, must leave it out. What both addons run the same way is in `shared/`, copied into each addon's `Shared/` folder: the event core, the debug log, the API check's machinery (KaLi Quest's assumptions stay in `Core/SelfCheck.lua`), the bug report and its window (KaLi Quest's sections stay in `UI/Report.lua`), the slash command dispatcher with the commands for debugging, and the in-game test harness, which gained KaLi Recipe's helpers for comparing tables and saved files. Visible changes for KaLi Quest: the report also strips item links' codes, and its address is the new repository's issues. The offline checks are the family's (`tools/kali/checks.py`); `python -I tools/run_tests.py` runs both addons'. The shared code's 25 deliberate breaks (`tools/breaks/shared.py`) are all caught by both addons' tests. Before its own checks existed (`tools/lua/smoke_shared.lua`, played by each addon's runner on its copy), most of them went unseen by one addon's tests or both: each addon had tested its copy only where its smoke session happened to use it. `quest/tools/gen_addon_data.py` needs the FieldJournal addon installed, for its research step, and it no longer is: the committed `Data/Sorts.lua` stands until it's back.

1. **Written, run in game on 2026-11-06; still to run:** the item button, `AddQuestWatch` at 25, the map pin, a login with the addon disabled, and the collapse check once more. **Ikar, 2026-11-07:** a follow-up quest kept its place, and the shaman class header was recognised. `KaLiQuest_Probe`. A small in-game probe: park the sections under the host, draw one test row and fire `AddBlock` for it, try a plain item button, print every log header with `headerSortKey`, print which sections can fill and what the tag, classification, location, search and next-step calls return for your current log, and test a full restart.
2. **Written, its 64 tests pass in game (2026-11-06):** `KaLiQuest`'s core. Categories, header classification, player's groups, placement rules including the follow-up rule, and events, with a slash command to inspect them and no UI yet. This includes a data-format step, tested by having the addon save an old-format table and reloading.
3. Tracker: the host, category bars, groups, quest rows, scrolling with the scrollbar, the combat lock, popups and menus, from [tracker-parity.md](tracker-parity.md). **First slice written on 2026-11-06, Ikar's go-ahead, tested offline only:** Blizzard's title, background and sections parked; the title row with collapse-all; Suivi, Journal and category bars with counts, double arrows and Suivi's +; groups with their eye and in-place rename; quest rows with the level badge, objectives, background and separators; moved quests' grey lines and the deleted group's undo line; mouse-wheel scrolling; clicks, shift-click and the menus of quests, groups and bars; Spoken's hook fired for each row; `/kq tracker off` to give Blizzard's tracker back. **Not yet:** the padlock and combat lock, the gear, the scrollbar, item buttons, popups, map buttons, markers, share and find-group buttons, tooltips, the glow, and the options panel. **My calls in this slice, confirmed by Ikar on 2026-11-08:**
    - The rows hang from the host while it shows, so Forever Quest Tint finds their titles, and from `UIParent` while Blizzard hides it for tracking nothing. Calling `Show` on the host would run Blizzard's frame manager from addon code, which risks taint (risk 2). A host never shown since login has no position, so the rows then top `RightManagedFrameContainer`, where the host would sit.
    - So Forever Quest Tint's ∞ only comes once something is tracked: it doesn't scan a hidden host. Seen in game on 2026-11-09: no ∞ with every group empty, and tracking a quest brought it back. **Ikar's ruling on 2026-11-09:** leave it at that for now. Not chosen: an ∞ marker of the addon's own, or asking Forever Quest Tint's author to look at this tracker once it's published.
    - Opening and closing work in combat until the padlock exists, since there are no item buttons yet to fall out of line.
    - Deleting a group doesn't ask first yet: the undo line covers a mistake.
    - While the addon's tracker is on, Blizzard's other sections are parked too: scenarios, widgets, bonus objectives, achievements, recipes and quest popups don't show until steps 3 and 4 add them. The timer panel stays.

    **Review fixes, 2026-11-06, before the slice's first run in game:**
    - **Parking waited for Blizzard's setup.** `ObjectiveTrackerManager:Init` runs once both `PLAYER_ENTERING_WORLD` and `VARIABLES_LOADED` have come, after `PLAYER_LOGIN`. It puts every section in the host with `SetContainer` → `SetParent`, which would have brought them all back on screen at every login and reload. The probe never saw this because its park was run by hand later. A section is now parked once it's in a container, and a secure hook on the host's `AddModule` parks any Blizzard adds later. Each section's saved parent is its container, so `/kq tracker off` gives it back to the host rather than to no parent at all.
    - A closed Journal is saved as `false`, because the default fills a missing value with open.
    - The whole quest box takes clicks, badge and background margins included, through `SetHitRectInsets`.
    - The quest menu matches Blizzard's: Ouvrir les détails de la quête (`QuestUtil.OpenQuestDetails`) is back, and Ouvrir la carte always opens the map. A row's click still opens the turn-in of a complete auto-complete quest.
    - Clicks, menu entries and the host's hooks run through `ns.SafeCall`, so their errors reach `/kq errors` as well as BugSack.
    - A change of the host's height, from Edit Mode or the screen, redraws at once.
    - Rows show the money a quest needs, as Blizzard's do, and the auto-complete lines keep their dash.
    - Focusing a quest opens its group, or its section and header, after the next frame's settle, so a quest a map button just tracked is found in its group. The focus restored at login doesn't count.
    - A quest listed before any header goes under `MISCELLANEOUS`; the list stops 10 above the host's bottom so the background stays inside it.

    **First in-game look, 2026-11-06:** Ikar found the slice good, apart from the level square, now lighter (see Quest rows), and said to continue.

    **Second slice written on 2026-11-06, tested offline only:** the padlock and the combat lock, as in [Combat](#combat), with the refused-click flash and a focus held until unlocked; the gear and its menu; the addon's page in the game's options, also reached from the addon compartment and `/kq options`; the title's buttons at half opacity until the pointer is over the tracker; Blizzard's `MinimalScrollBar`, invisible unless scrolling or hovered, which the combat lock stops too; tooltips on rows, moved lines, the padlock and the small buttons, and Blizzard's `OnQuestBlockHeader.OnEnter` event for other addons; the four key bindings in `Bindings.xml`. New files, so a full restart is needed. **My calls in this slice, confirmed by Ikar on 2026-11-08:**
    - The gear's menu has only Suivi automatique de quête and Options for now. The glow and area highlight switches join it with their features, so no switch does nothing.
    - The options page holds the tracker's on/off switch and auto-tracking until the rest of [Options](#options) is built.
    - Until search and filter exist, the padlock and gear sit next to collapse-all, at 21 and 42 from the right, rather than leaving gaps for them.
    - A row's tooltip appears only in a party (Blizzard's party progress) or before the first group (the hint), as Blizzard's shows none solo. Since Ikar's ruling on 2026-11-10, not in a party either.
    - The flash is a swell to 1.35 and a red glow over 0.45 s, the bench's values; the scrollbar fades out over 0.4 s, 0.8 s after the last scroll.

    **Second review's fixes, 2026-11-06, still offline only:**
    - Locked in combat, the scrollbar is switched off with `SetScrollAllowed`, and pressing it flashes the padlock. Putting the list back after a refused scroll stops at the list's end: past it, Blizzard's bar and the lock could have pushed the list back and forth until a stack overflow.
    - `OnQuestBlockHeader.OnEnter`'s last value now says whether a tooltip is already up, as Blizzard means it, so other addons add to the first-group hint rather than wiping it. The hint sits under the quest's title, since a tooltip's first line takes the header font.
    - A focus removed while locked no longer opens its group once unlocked.
    - The title row wakes its buttons too, taking the pointer but not clicks. The gaps between rows don't: taking the pointer there would stop it reaching units behind the tracker.
    - A refused key binding wakes the title's buttons, so its flash shows in full. The padlock's tooltip follows the start and end of a fight, and the gear's says it can't open in combat.
    - The options page registers in its own login handler, so it and the compartment's entry exist even if the tracker fails to start.

    **Third slice written on 2026-11-07, with steps 6 and 8, tested offline only:** step 3's remainder, then search and filter, then drag and drop, Ikar's go-ahead. New files, so a full restart is needed.
    - **Rows:** Blizzard's map button at the title's left while the map's quest objectives are on, its find-group eye, and quest items on secure buttons (see [Combat](#combat)), with range, charges, cooldown, the area glow and shift-click to link. A progress bar for progress-bar objectives, the next step under a focused quest, party counts as `[2]`, links in objective text, and a sequenced quest's steps only as reached.
    - **Popups:** Blizzard's "Quête découverte !" and "Cliquer pour terminer la quête" under the title, full size, scaled with the text up to the tracker's width. Hidden while the tracker is collapsed, but a new one opens it, as Blizzard's does.
    - **Motion:** a new quest's row sweeps in, or its closed header glows; progress glows a row once (the gear's Lueur switch); finished objectives check off, a completed quest's lines fade before its completion text; a quest turned in or removed fades where it was. A quest accepted in combat waits for the fight's end.
    - **Options page:** width, height and text size (the last two follow Edit Mode until set here, and whichever changed last wins), the block's three opacities, the tracker's opacity in and out of combat, header saturation, the find-group eye, and an Avancé section for gaps and indents. The text size became a zoom on 2026-11-10, Ikar's ruling (see [Options](#options)).
    - **Deleting a group with quests** now asks first, with a `StaticPopup`. An empty one goes at once, with the undo line.
    - **Search and filter,** as [filter-search.md](filter-search.md). The magnifying glass and filter sit left of the padlock and gear. Text typed in combat applies when the fight ends.
    - **Drag and drop,** as [Interaction](#interaction).

    **My calls in this slice, confirmed by Ikar on 2026-11-08:**
    - With no match, the status line keeps Tout effacer after "Aucun résultat trouvé", so a filter that hides everything can be cleared from there.
    - A bar or header holding a new quest glows only if that quest's row isn't drawn.
    - The Options page's Defaults set height and text size to fixed values rather than back to following Edit Mode. Since 2026-11-10, height and the zoom.

    **Review's fixes, 2026-11-07, still offline only.** A full review found five bugs the checks missed, each reproduced offline before fixing, and each now has a check:
    - A quest dropped back on its own row moved near the end of its group. It now stays.
    - A drop anywhere at a group's height, even far beside the tracker or over rows scrolled away under the title, landed in that group. Only the list on screen takes a drop now.
    - A charge used from a quest item in combat redrew the whole tracker five times a second until the fight ended. It now redraws once.
    - A row fading out of the log kept an item button, sometimes another quest's. It now has none, and can't be dragged or clicked.
    - Escape or the search box's clear button in combat changed the rows at once. The rows now wait for the fight's end, as typed text does.
    - Also: the find-group check no longer goes through `QuestUtil`'s cache (risk 19); a new popup opens a collapsed tracker; the drop line sits above the rows; a drag the game never ends, as when its row hides, ends when the button comes up; highlights are reused instead of piling up; the dragged copy follows the tracker's scale; a quest accepted in combat sweeps in once the fight ends; the title glow spans the row; a fading row keeps its progress bar's value; fonts are set again only when a size changes, and a size of the addon's own uses Blizzard's `ObjectiveTrackerFont<size>` families, so other alphabets keep their fonts; search also reads reward currencies and spells, and asks once for rewards not loaded; saved filters, Journal's order and sizes are checked at load.

    **My calls in the review's fixes, confirmed by Ikar on 2026-11-08:**
    - A popup arriving in a fight opens the collapsed tracker once the fight ends, as rows don't move under item buttons in combat. The padlock doesn't hold it back, since a popup is the game's doing and would stay unseen.
    - Shift-click on a quest item: with a chat box open it links the item, otherwise it uses it, as Blizzard's. In combat attributes can't change, so there a shift-click only links.
    - Suivi's top 4, under the title, takes no drop, like the title itself.

    **Third review's fixes, 2026-11-09, tested offline only.** A review on 2026-11-08 found eight bugs, each reproduced offline first and each now with a check that fails without its fix:
    - Every login and reload logged a Lua error in Blizzard's `NineSlice.lua`: the background was made from `NineSlicePanelTemplate`, whose setup reads a parent the frame doesn't have yet. It's a plain frame given the same art now. The error reached the game's log, not `/kq errors`.
    - A tracker turned off in a fight left its item buttons on screen, clear but clickable, after it. They go once the fight ends.
    - In a fight, a quest leaving the log above one with an item made that item's tooltip, charges, range and cooldown read the wrong quest. A button now reads its quest's place each time.
    - Coming back after Blizzard's tracker showed, what changed meanwhile replayed: quests that left faded again, progress glowed, achievements earned played their turn-in, new ones and new bars slid in, and the area highlight learnt where the player stood then as the place of that progress. Nothing replays now.
    - Déplacer vers its own group, the ticked entry, moved a quest to its group's end. It stays now.
    - A refusal with no text, such as accepting the delete question once the group has gone, printed "missing". It says the group no longer exists.
    - The Diagnostic panel's last lines ran under its buttons with debug on. Its lines scroll.
    - Astuces: a quest's link goes into chat on Maj+clic, not a plain click; the area count shows on any bar or group holding such quests, open or closed.
    - Also: clicking a finished auto-complete quest's row takes its popup away, as Blizzard's; item buttons follow the tracker when it moves with no redraw, as with the UI scale or the right-hand frames shifting; saved option numbers are brought inside the options page's ranges at load; a group's name stops at 40 letters, as the rename box does; the compartment's click says why when the saved data was refused; `/kq errors` lists the latest first. The test fake now runs `NineSlicePanelTemplate`'s setup and gives buttons the mouse from the start, as the game does; those two gaps had let the first two bugs through.

    **My calls in these fixes:** saved numbers outside a range are clamped to its nearest end, and NaN takes the default; a longer group name is cut at 40 letters rather than refused; `/kq errors` sorts by last time, then by count.
4. **Written on 2026-11-07, Ikar's go-ahead, tested offline only:** other sections. The probe found `C_TradeSkillUI.GetRecipesTracked` and `C_ContentTracking.GetTrackedIDs` answering, empty, so recipes and achievements came first, in `UI/Sections.lua`. Each has a bar of its own below Journal, shown only while something is tracked, as Blizzard's "Métier" and "Hauts faits": recipes list their required reagents, modifying ones first, `have / need name`, checked once met, and wait for an item's name to load; achievements list up to five unfinished criteria, then "...", with ones that can't be had any more in the failed colour. Clicks, chat links, the modified click that stops tracking and the menus are Blizzard's. **My calls, confirmed by Ikar on 2026-11-08:** the two bars start open, as the player has just tracked something; a search or filter hides them, since they aren't quests. Achievement timer bars (Blizzard's AC5) came on 2026-11-08, with the turn-in animation (see below). Scenarios, widgets, bonus objectives and the rest wait for the probe to show they can fill.
5. **Written on 2026-11-07, tested offline only:** markers and the share button. Icons only where the row's place doesn't say it: the off-list pin first, then dungeon, raid and PvP outside their own category, at most three, inline after the title's last word, sized by the advanced "Marker size" (13), and named in the row's tooltip until Ikar's ruling on 2026-11-10 (icons only). The share button sits right of the item, only in a party where someone lacks the quest, and by default only under the pointer ("Bouton de partage au survol seulement"), its room kept so the title doesn't rewrap. **2026-11-08:** I had left out the other markers, misreading the ruling of 2026-11-06; Ikar corrected it, and the addon now draws every marker of the table, as the bench does: timed, group size (its number after the icon, where the bench puts it on the icon), repeatable, daily or scheduled, weekly, legendary (tag 83), and class for a quest moved into Suivi from a class header. Still offline only.

    **Review's fixes, 2026-11-07, still offline only:**
    - An error while drawing now gives Blizzard's tracker back for the session and says so in one line, with `/kq tracker on` to retry ([tracker-parity.md](tracker-parity.md) "How it works" 8). The saved choice stays on, so the next login tries again.
    - Bags, currencies and item data come often, so they redraw only while a recipe is tracked or an item's name is awaited. Achievement criteria redraw through `TRACKED_ACHIEVEMENT_UPDATE` only, as Blizzard's, rather than on every criterion in the game.
    - A recipe shows once all its items' names have loaded, as Blizzard's, rather than line by line.
    - Closing and reopening Métier or Hauts faits, or clearing a search, no longer fades their entries in as new.
    - Raid quests for 10 and 25 players (tags 88 and 89) get the raid icon and count as Raid in the filter.
    - The share button hides once the pointer leaves the row's box, even through the eye, the item or the map button, and stays while the pointer is on the map button.
    - The filter, search and collapse-all icons brighten on hover with an added copy, as Blizzard's highlights do, instead of a colour above 1.

    **Still open from the review:** a section the addon doesn't draw now makes it step aside for Blizzard's tracker while it has contents, Ikar's ruling on 2026-11-07, rather than a safety net under the rows ([tracker-parity.md](tracker-parity.md) "How it works" 7); `/kq diag` opens a live debug panel. The probe saw no scenario and no bonus objectives in Dun Morogh, but a widget set (240) there and collection tracking switched on. An earned achievement now plays Blizzard's turn-in, on 2026-11-08 with Ikar's go-ahead: it keeps its place, the glow sweeps its title and it fades out over 0.66 s, or goes at once if its bar is closed. A newly tracked one fades in with the glow sweeping its title, as Blizzard's AddAnim, and so does a recipe. Timer bars (AC5) are Blizzard's: under a criterion with a running timer, and for an achievement without criteria from `TRACKED_ACHIEVEMENT_UPDATE`, whose run-out timer turns it the failed colour. The arena-only list (AC1) isn't needed: this client has no arena map. Achievement and recipe clicks are refused in combat, as quest windows are, where Blizzard's open; they open Legacy Challenges and the professions window from the addon's code, so they join the taint test (risk 19).
6. Search and filter.
7. ~~The native log's Déplacer vers menu.~~ Dropped, Ikar's ruling on 2026-11-07.
8. Drag and drop.
9. **Written on 2026-11-07, Ikar's go-ahead, tested offline only:** the area highlight, as [Area highlight](#area-highlight-optional-on-by-default) describes.
10. ~~Version 2, the organiser window.~~ Dropped, Ikar's ruling on 2026-11-07.
