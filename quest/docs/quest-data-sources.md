# Quest data for grouping below zone level

Researched 2026-11-06 against WoW Forever build 1.60.1.70790. Reproduce the measurements with `python -I quest/tools/research/subzone_poc.py` and `python -I quest/tools/research/objective_location_test.py` (they read the FieldJournal addon's labels, so it must be installed).

**Status: reference only.** The addon's plan is now for players to organise quests themselves, in [organiser-design.md](organiser-design.md). Automatic grouping below zone level isn't planned. This research remains for the optional area highlight and other location features. Class and dungeon groups are covered in [quest-properties.md](quest-properties.md).

## Summary

**The game has no direct way to ask which sub-zone a quest belongs to.** The quest log groups by zone, the map hierarchy stops at zone, and no quest function returns a sub-zone. Grouping has to be assembled from other signals.

The best automatic option would group by **where to go next**: the objective's place until it is done, then the turn-in. It is feasible, provided a quest with no single place stays at zone level instead of being guessed. Names can appear in French automatically if we store area IDs.

| Priority | Signal | When available | Coverage | Needs a dataset? |
| --- | --- | --- | --- | --- |
| 1 | Your manual choice | Always | Whatever you set | No |
| 2 | Sub-zone recorded when an objective progresses | Live, in French | Quests you have progressed (not measured) | No |
| 3 | Blizzard's own waypoint, if it works on Forever | Live | Unknown, section 7 | No |
| 4 | Objective's spot, or the turn-in when nothing else is left, from a bundled table | Always | 72% of vanilla quests get one place. New quests: 39% have objective coordinates, 76% a turn-in | Yes, GPL-3.0 |
| 5 | Instance or city name | Always | 9% of vanilla quests | Yes, GPL-3.0 |
| 6 | Plain zone group, never a guess | Always | Everything left | No |

Nothing here has run in-game. Section 7 lists what still needs a live test. The result that matters most: if `C_QuestLog.GetNextWaypoint` or `GetQuestsOnMap` return objective coordinates on Forever, the game already answers this for every quest in the log, including new ones.

## 1. What "sub-region" should mean

A quest has up to three places, and they often differ:

| Comparison | Both places known | Same area |
| --- | --- | --- |
| Giver and turn-in | 3,291 quests | **75%** |
| Giver and objectives | 1,164 quests | **28%** |
| Objectives and turn-in | 1,205 quests | **29%** |

The median distance from giver to objective is 16% of the map's width, and 45% at the 90th percentile.

So there are two different groupings:
- **Where to go next** (objective until complete, then turn-in): the better automatic option. A quest changes group when its objective finishes. Section 2a tests it directly.
- **Hub grouping** (giver or turn-in): stable, and matches "my Goldshire quests", but it doesn't say where the work is.

## 2. How well each signal works, against FieldJournal's labels

Scored against `FieldJournal`'s 743 hand-written `subregion` labels, 738 of which match a quest in the data.

| Signal | Answered | Same name | Group precision | Group recall | Group F1 |
| --- | --- | --- | --- | --- | --- |
| Place named in objective text | 290 | 64% | 0.60 | 0.82 | **0.70** |
| Turn-in in a map overlay area | 603 | 54% | 0.49 | 0.80 | **0.61** |
| Turn-in or giver, nearest town | 472 | 48% | 0.48 | 0.83 | **0.61** |
| Turn-in, else giver | 708 | 51% | 0.48 | 0.71 | 0.57 |
| Objective text, turn-in, giver | 708 | 53% | 0.49 | 0.66 | 0.56 |
| Any text, turn-in, giver | 711 | 55% | 0.50 | 0.62 | 0.55 |
| Giver, nearest town | 473 | 45% | 0.41 | 0.81 | 0.55 |
| Place named in quest description | 301 | 52% | 0.54 | 0.54 | 0.54 |
| Giver in a map overlay area | 604 | 47% | 0.40 | 0.69 | 0.51 |
| Objectives in a map overlay area | 318 | 42% | 0.47 | 0.38 | 0.42 |

Group scores compare whether two quests land together, regardless of the name. Precision is how often quests grouped together belong together. Recall is how often quests that belong together end up together.

The objective-text row covers vanilla quests only, because the text came from QuestieDB's Era baseline. So its 290 answers come from 491 tested quests, not 738. The location rows include new quests, which makes the comparison imperfect.

**These compare signals against each other. They are not accuracy.** The labels aren't ground truth:
- They use a different vocabulary: 206 distinct labels, 21 of which aren't area names in the game.
- Many disagreements are both right: "Northshire Abbey" and "Northshire Valley", or "Eastvale Logging Camp" and "Tower of Azora" for the same quest giver.
- They come from one addon author and seem to reflect story as much as geography.
- They lean towards the hub. Where objective and hub differ (182 quests), a label names the giver's or turn-in's area 84 times, the objective's 47 times and neither 51 times. So **the objective row's 0.42 is not a mistake rate**, and section 2a replaces it.

Two rows in this table are not what they appear to be:
- "Place named in objective text" mostly names the turn-in, because most such text reads "Bring X to Y in Goldshire". It is a hub signal, and it says little about where the objective is.
- "Objectives in a map overlay area" answered 318 of 738, but many of the rest have no objective at all, so it isn't a coverage figure either.

Judging real quality needs your eye. A sample grouped by giver location, which was the simplest signal to list. Stormwind's quests are left out of Elwynn here (see section 8):

| Zone | Groups (quest count) |
| --- | --- |
| Westfall | Sentinel Hill (20), Saldean's Farm (12), The Dagger Hills (9), Stonefield Farm (5), Maclure Vineyards (3), The Jansen Stead (3), Moonbrook (3), Westfall Lighthouse (3) |
| Elwynn Forest | Goldshire (46), Northshire Valley (31), Tower of Azora (11), Eastvale Logging Camp (7), Crystal Lake (5), Forest's Edge (3) |
| Zephras Isle | Valanaar (45), Shen'dar Village (36), Thendal Village (23), Shadowgale Forest (9), Windfield Orchard (7) |

Across all maps, in that same run: a median of 9 groups per zone (max 24) and 4 quests per group (max 114). 1,338 of 4,870 quests were left unplaced in this run, including those with no known giver and those on maps without overlays such as capital cities.

**French test.** Matching French objective text against French area names found a place in 240 of 491 labelled vanilla quests, against 291 in English. So the live signal works in French, somewhat less often. Elided articles and inconsistent translations are the likely cause, so matching needs tolerance. For example, `AreaTable` gives "Comté-de-l’Or", and French text may use a different form of a name.

## 2a. Direct test of objective location

**Reference:** 71 vanilla quests whose own objective text states where the objective is, such as "Kill Bristlebacks in Brambleblade Ravine". Text naming only a giver or turn-in is filtered out. I read every entry before seeing any score and removed 3 that named two places or a later step.

**Method:** the spot holding the most objective spawns within 300 yards, with each objective weighted equally.

| Distance from that spot to the stated area's map rectangle | Stated area | Control: a random other area of that zone |
| --- | --- | --- |
| Inside | 77% | 3% |
| Within 150 yards | 92% | 7% |
| Within 300 yards | **94%** | 15% |
| Within 600 yards | 96% | 32% |

On the same group measure as section 2, this scores **0.88** (precision 0.88, recall 0.88). The old median-spawn method also scores 0.88 here, so the method didn't cause the difference: the reference did. Against FieldJournal's labels, both still score 0.42 to 0.43.

**The four misses** (67 of 71 within 300 yards):
- "Blueleaf Tubers", 3,542 yards off: a multi-step quest, where the data points at another step.
- "Rin'ji is Trapped!", 1,569 yards off: an escort with one recorded point.
- "Lost!", 718 yards off: one recorded point.
- "Skull Rock", 392 yards off: at the area's edge.

**Names are weaker than positions.** The map rectangles give the stated name for 52 of 71 quests (73%), or 56 (79%) when a spot snaps to the nearest area within 200 yards. That snapping rule was designed after seeing this set, so 79% may flatter it. Failures are an empty spot on the map or a neighbouring area, such as "Moonglade" for Lake Elune'ara. Names recorded live from `GetSubZoneText()` avoid this.

**Limits of this test:**
- It is small, vanilla-only and a best case. Quests that state a place tend to have one site: 62 of the 71 have 90% or more of their spawns in one spot.
- Some Alliance and Horde twin quests are in the set, so the 71 aren't fully independent.
- New Forever quests are untested. Their text isn't in this data.

### What share of quests gets one answer

Every vanilla quest, 3,908 in all:

| What the quest needs | Quests | Share | Answer |
| --- | --- | --- | --- |
| Nothing but a hand-in, turn-in known | 1,717 | 44% | The turn-in's place |
| Objective in one place (60% or more of spawns in one spot) | 1,076 | 28% | That place |
| Objective in several places | 559 | 14% | Zone level, no guess |
| Objective with no coordinates | 500 | 13% | See below |
| Nothing but a hand-in, turn-in unknown | 56 | 1% | Zone level |

The 500 with no coordinates: 356 are in instances or cities (the instance or city name is a fair group), 59 have no spawns in QuestieDB, 47 have open-world spawns missing from Zmap's table (recoverable from QuestieDB), 26 need only a vendor or crafted item, 11 are reputation or similar and 1 is a trigger with no coordinates.

**New quests:** 374 of 962 have objective coordinates, and 84% of those are one place. A third of all quests with coordinates rest on a single spawn point (612 of 2,009), so some new-quest data may simply be thin. From data on disk, the other 588 can't be split into "no objective" and "objective not recorded". `C_QuestLog.GetQuestObjectives` answers that live.

### What a log would look like

1,509 simulated logs: 8 quests from one zone, within 4 levels, one faction, with one-place objectives only.

| Grouping | Groups per log (median) | Quests sharing a group (median) |
| --- | --- | --- |
| By distance, every pair within 500 yards | 4 | 75% |
| By named area from map rectangles | 6 | 50% |

Distance gives more useful groups but has no name of its own, while rectangles give names but split quests that sit close together. Real logs may cluster more than random samples do, since players take quests in batches.

## 3. Live API: quest identity and classification

Available any time, with no restriction flags in Blizzard's docs. Full list in [quest-api-inventory.md](quest-api-inventory.md).

| API | Gives | Use for grouping |
| --- | --- | --- |
| `C_QuestLog.GetInfo(index)` | title, questID, level, `difficultyLevel`, `suggestedGroup`, `frequency`, `isHeader`, `isCollapsed`, `isTask`, `isBounty`, `isStory`, `isScaling`, `isOnMap`, `hasLocalPOI`, `isHidden`, `isAutoComplete`, `overridesSortOrder`, `headerSortKey`, `campaignID`, `questClassification` | Zone (from the header row) and type |
| `C_QuestLog.GetHeaderIndexForQuest` | The quest's header row | Zone level |
| `C_QuestLog.GetQuestTagInfo` | `tagName`, `tagID`, `isElite`, `quality` | Dungeon, raid, elite, group |
| `C_QuestLog.GetQuestObjectives` | `text`, `type`, `finished`, `numFulfilled`, `numRequired`, `objectiveType` | Text matching, progress |
| `GetQuestLogQuestText(index)` | Description and objective text, localised (undocumented) | **Place-name matching** |
| `GetQuestLogLeaderBoard`, `GetQuestObjectiveInfo` | Objective lines (undocumented) | Text matching |
| `C_QuestLog.GetTitleForQuestID`, `GetQuestLink` | Names | Display |
| `C_QuestLog.IsComplete`, `ReadyForTurnIn`, `IsFailed` | State | Status groups |
| `C_QuestLog.IsEliteQuest`, `IsRepeatableQuest`, `IsQuestTrivial`, `IsAccountQuest`, `IsImportantQuest`, `IsMetaQuest` | Traits | Filters |
| `C_QuestLog.GetSuggestedGroupSize`, `GetQuestDifficultyLevel`, `GetTrivialRange`, `GetTimeAllowed`, `GetRequiredMoney` | Details | Sorting |
| `C_QuestInfoSystem.GetQuestClassification` | Campaign, questline, and so on | Type |
| `C_QuestLog.IsPushableQuest`, `IsUnitOnQuest`, `C_TooltipInfo.GetQuestPartyProgress` | Party state | Group play |
| `GetQuestExpansion`, `GetQuestFactionGroup`, `IsBreadcrumbQuest`, `IsStoryQuest`, `QuestIsDaily`, `QuestIsWeekly` | Undocumented traits | Filters |

"Undocumented" means the function exists in `BlizzardInterfaceResources`, one build behind, but Blizzard's docs don't describe it. Existing isn't proof of working: Questie's maintainers found Forever legacy functions that exist but fail internally, for watch count, aura and mouse-over.

Quest categories come from the `QuestSort` table (39 rows): classes, professions, Seasonal, Darkmoon Faire, Reputation, The High Order, Camping and others. Around 23% of Era-baseline quests (983 of 4,244) use one of these rather than a zone.

## 4. Live API: quest location

| API | Gives | Likely on Forever | Evidence |
| --- | --- | --- | --- |
| `C_QuestLog.GetQuestsOnMap(uiMapID)` | Pins: questID, x, y | **Sparse?** Must test | Used in 3 installed files, 2 of them Zmap's. `QuestPOIBlob` holds only 22 quests in client data, though the server may add more |
| `C_QuestLog.GetNextWaypoint(questID)` | mapID, x, y | Unknown | Blizzard's log uses it. One installed file does |
| `C_QuestLog.GetNextWaypointForMap` | x, y on a given map | Unknown | No installed addon uses it |
| `C_QuestLog.GetNextWaypointText` | Text | Unknown | Blizzard's tracker uses it |
| `GetQuestUiMapID(questID, ignoreWaypoints)` | uiMapID, zone level at best | Unknown | Blizzard uses it. Undocumented |
| `C_QuestLog.IsOnMap(questID)` | `onMap`, `hasLocalPOI` | Probably | Same data as `GetInfo` |
| `C_QuestLog.GetDistanceSqToQuest` | Squared distance from player | Unknown | No installed addon uses it. Good for sorting if it works |
| `C_Minimap.IsInsideQuestBlob(questID)` | Is the player inside the objective area? | Sparse | Blizzard's item button uses it |
| `GetQuestPOIs`, `GetQuestPOIBlobCount`, `QuestHasPOIInfo` | POI data | Sparse | Undocumented, no installed addon uses them |
| `C_TaskQuest.GetQuestLocation`, `GetQuestZoneID` | Location for task quests | Rarely useful | Only bonus-type quests |
| `C_QuestLine.GetQuestLineInfo`, `GetQuestLineQuests` | Storyline and start position | **Almost empty** | `QuestLine` table has 3 rows |
| `C_AreaPoiInfo.GetQuestHubsForMap` + `C_QuestHub.IsQuestCurrentlyRelatedToHub` | Literally quest hubs | **Test first** | Would be ideal, but every `AreaPOI` row has `PoiDataType` 0 |
| `C_QuestLog.GetQuestAdditionalHighlights` | Map highlights | Unlikely | World-quest oriented |

## 5. Live API: places

| API | Gives | Notes |
| --- | --- | --- |
| `GetSubZoneText()`, `GetMinimapZoneText()` | Player's sub-zone, localised | **Reliable.** Blizzard's zone text uses it, as do 19 installed files. Blank in some places |
| `GetRealZoneText()`, `GetZoneText()` | Player's zone | Reliable |
| `C_Map.GetBestMapForUnit("player")`, `GetPlayerMapPosition` | Player's map and coordinates | Open world |
| `C_Map.GetAreaInfo(areaID)` | **Area name in the client's language** | Confirmed live by Questie's maintainers. This is why we store IDs |
| `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapID, pos)` | Area IDs at a point | **Explored areas only.** Blizzard's map hover uses it |
| `C_MapExplorationInfo.GetExploredMapTextures(uiMapID)` | Overlays with hit rectangles | Explored only. 9 installed files use it |
| `C_Map.GetMapInfoAtPosition`, `GetMapChildrenInfo` | Child maps | **No use.** Forever has no micro-maps: of 60 `UiMap` rows, 51 are zones and none are micro |
| `C_Map.GetMapPosFromWorldPos`, `GetWorldPosFromMapPos`, `GetMapRectOnMap`, `GetMapWorldSize` | Coordinate conversion | Useful for overlapping zone rectangles |
| `C_AreaPoiInfo.GetAreaPOIForMap`, `GetAreaPOIInfo` | Named map points | Must test. The `AreaPOI` table has towns |
| `C_TaxiMap.GetTaxiNodesForMap` | Flight points | Anchors for hubs |

### Learning locations during play

Nothing below needs a dataset, and it improves over time:

| Moment | Event | Record |
| --- | --- | --- |
| Offered a quest | `QUEST_DETAIL` | Player's sub-zone and position, giver via `UnitName("npc")` |
| Accepting | `QUEST_ACCEPTED` | Same, keyed by quest ID. Slightly noisy: shared or item-started quests |
| Objective progress | `QUEST_WATCH_UPDATE`, `QUEST_LOG_CRITERIA_UPDATE` | Where objectives actually happen |
| Handing in | `QUEST_COMPLETE`, `QUEST_TURNED_IN` | Turn-in place, useful for quest chains |
| Hovering a quest mob | `C_TooltipInfo.GetUnit`, `QuestTitle` and `QuestObjective` lines | Mob-to-quest link. Questie saw this out of combat. Values can become secret in combat |
| Changing area | `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED_INDOORS` | Current location for sorting |

`FieldJournal` already falls back to `GetSubZoneText()` when it has no label, though at turn-in time.

### Quests to pick up, on the map

Ikar's question on 2026-11-08: can the map show quests the character could take, with the live API only and no bundled database? Research only, nothing built.

- **No API lists a zone's quests or its quest givers.** Blizzard's own map offers (`Blizzard_SharedMapDataProviders/QuestOfferDataProvider.lua`, 173-214) come from `C_QuestLine.GetAvailableQuestLines`, `C_QuestLine.GetForceVisibleQuests`, task quests and `C_AreaPoiInfo.GetQuestHubsForMap`. On Forever that's 3 quest lines and no quest hubs, so it shows almost nothing. The minimap's "!" for nearby givers is drawn by the engine, and no function reads it.
- **What the API does give, at a giver:** `C_GossipInfo.GetAvailableQuests()` (questID, title, questLevel, isTrivial, repeatable…), `GetNumAvailableQuests` and `GetAvailableQuestInfo(i)` on a greeting, `QUEST_DETAIL` with `GetQuestID()`, the giver's NPC ID from `UnitGUID("npc")`, and the player's map and position. **For any quest ID:** its title (`C_QuestLog.GetTitleForQuestID` after `RequestLoadQuestByID`), whether it's done (`IsQuestFlaggedCompleted`, `GetAllCompletedQuestIDs`) and whether it's in the log (`IsOnQuest`).
- **So the only database-free way is remembering.** Each giver talked to is saved, account-wide: NPC ID, map, position and what it offered. The map shows a "!" where an offered quest isn't done yet, so an alt benefits from the main's travels. Talking to the giver again corrects the list for that character, as Zmap and Wayfinder do. Limits: only givers someone has talked to; for a quest not yet offered to this character, its level is the one seen at the giver, and its class, race and prerequisites are unknown; items and objects that start quests are learned only when used. Addon messages to the party or guild could pool what each player learned, still without a database.
- **Installed addons already do parts of this.** Zmap's "Quêtes à prendre" layer shows every giver from its bundled QuestieDB Forever data (GPL-3.0), filtered by level, race, class and quests done, and hides what a giver turns out not to offer (`Zmap/Modules/QuestMap.lua` 56-80 and 527-561). It's off in Ikar's settings (`available = false` in `SavedVariables/Zmap.lua`). Wayfinder remembers offers per character (`Wayfinder/QuestAvailability.lua`).
- **Where pins can go.** Zmap draws its own `ZmapFrame`, which can replace the map key, with its own pins and no API for other addons. A pin added to Blizzard's `WorldMapFrame` with `AddDataProvider` wouldn't show there.

## 6. Data outside the live API

### Client game tables, via wago.tools

Downloaded to `reference/db2/1.60.1.70790/` from `https://wago.tools/db2/<Table>/csv?build=1.60.1.70790`. Add `&locale=frFR` for French. Used to build a dataset, not readable by an addon at runtime.

| Table | Rows | What it offers |
| --- | --- | --- |
| `AreaTable` | 1,375 | **The sub-zone hierarchy.** 183 top-level areas, 1,192 children via `ParentAreaID`, almost all one level deep. Elwynn has 26 children |
| `WorldMapOverlay` | 1,081 | **Coordinates to area.** Hit rectangles plus up to 4 area IDs each. Covers 641 of 1,192 sub-zones |
| `UiMapXMapArt`, `UiMapArt`, `UiMapArtStyleLayer` | 60, 144, small | Link overlays to maps. Canvas is 1002 x 668 |
| `UiMapAssignment` | 61 | World bounds per zone, for converting world coordinates |
| `UiMap` | 60 | Map hierarchy. No micro-maps |
| `AreaPOI` | 372 | Named places with world positions and area IDs, mostly towns |
| `TaxiNodes` | 101 | Flight points |
| `WMOAreaTable` | 52,737 | Named rooms inside buildings. Too fine, mostly |
| `AreaTrigger` | 333 | Trigger volumes, positions only |
| `GameObjects` | 1,526 | Placed objects with positions |
| `Creature` | 184 | Client-side NPC records only. No spawns |
| `QuestV2` | 6,616 | Valid quest IDs and little else. 3,081 aren't vanilla; many are probably internal flags |
| `QuestPOIBlob`, `QuestPOIPoint` | 57, 121 | Native quest areas for just 22 quests |
| `QuestLine`, `QuestLineXQuest` | 3, 22 | Almost nothing |
| `QuestSort`, `QuestInfo` | 39, 7 | Categories and tags |
| `Criteria`, `CriteriaTree` | 3,291, 6,759 | Achievement criteria |
| `GlobalColor` | Small | UI colours |

Not offered for this build (HTTP 400): `QuestHub`, `QuestObjective`, `QuestV2CliTask`, `QuestXGroupActivity`, `UiMapLink`, `UiMapGroupMember`, `ZoneStory`, `Campaign`, `CampaignXQuestLine`, `WaypointNode`, `WaypointEdge`, `WaypointSafeLocs`.

### Datasets on disk

| Source | What it has | Coverage | Licence | How to use it |
| --- | --- | --- | --- | --- |
| **QuestieDB** (`reference/QuestieDB`) | Quests: giver, turn-in, objectives, `objectivesText`, `zoneOrSort`, `triggerEnd`, chains, reputation. NPCs: `spawns`, `waypoints`, `zoneID`. Objects, items with drop sources. French text | Era baseline 4,244 quests. New Forever quests come through corrections, and the maintainers say coverage is incomplete | GPL-3.0 | **Best source for a build step.** Spawns are keyed by area, more reliable than Zmap's maps |
| **Zmap** (`Data/Quests`, `Npcs`, `Objects`) | The same data flattened, plus places to reach | 4,870 quests, 962 not vanilla. Giver known for 91% of vanilla, 68% of new. Turn-in 95%, 76%. Objectives 42%, 39% | GPL-3.0 | Good for prototyping. Private to Zmap at runtime |
| **FieldJournal** (`Lore/QuestDB.lua`) | `zone`, literal `subregion`, `npcName`, `summary` | 743 quests, 252 new, 24 zones | **No licence found: do not copy** | Its table is a global, so an optional runtime read is possible for players who have it |
| **Spoken_Places** (`Data/*/Subzones.lua`, `Aliases.lua`, `ForeverAreas.lua`) | Sub-zones per zone, name aliases in 10 languages, Forever-only areas | All zones | Code MIT, text CC BY-SA 4.0 | Useful reference for French matching |
| **Spoken_Quests** (`Data/QuestText.lua`) | Accept and complete text, English | Thousands of quests | Check per file | Its table is a global. Better to read live text |
| **LoreForever** (`Data/Z_*.lua`, `Index.lua`) | Lore entries per zone, sub-zone capture | 5,064 entries | Text CC BY-SA | Not quest-structured |
| **ForeverQuestTint** (`VanillaQuests.lua`) | Which IDs are vanilla | Vanilla ranges | GPL-3.0 | Distinguishes new quests |
| **AutoBiographer** (`Data/NpcDatabase_Vanilla.lua`) | NPC data | Vanilla | Check | Not needed |
| **Wayfinder** (`Data/Seed.lua`, `MapOverlays.lua`) | Town services, overlay art | Towns | GPL-3.0-or-later | Not needed |
| **Client cache** (`Cache/WDB/frFR/questcache.wdb`) | Quests your client has seen | Tiny: 11 KB here | Game cache | Format not parsed, not needed |
| **Your saved variables** (`WTF`) | Possibly recorded quests from your addons | Unknown | Yours | Not read, since you declined earlier |

### External sites

| Site | State |
| --- | --- |
| `wago.tools` | **Works** for this exact build |
| `forever.warcraftdb.com` | Has a quest list, but renders through JavaScript. No bulk download found. "All Rights Reserved" |
| `wowhead.com/forever` | Blocks automated access (HTTP 403) |
| `Questie/dbc` | Questie's table exports, cited by QuestieDB. Not checked directly |
| Everloot, UlDungeonCompanion, EldoUI, AEGIS: Pathfinder | Other Forever quest data projects, from search results only. Not assessed |

## 7. Tests only the live client can answer

These decide what is worth building. A small probe addon could gather them all from your current quest log:

1. For each quest in your log, what do `GetQuestsOnMap`, `GetNextWaypoint`, `GetQuestUiMapID`, `IsOnMap` and `GetDistanceSqToQuest` return? **This matters most.** If they give objective coordinates, no bundled table is needed.
2. Does `C_AreaPoiInfo.GetQuestHubsForMap` return anything for a Forever zone? If so, test `C_QuestHub.IsQuestCurrentlyRelatedToHub`.
3. Does `C_QuestLine.GetQuestLineInfo` ever return data?
4. Does `GetExploredAreaIDsAtPosition` return sub-zones as expected? How do rectangles compare with `GetSubZoneText()` at the same spot?
5. What does `GetQuestLogQuestText` return in French, and how often does it name an area?

## 8. Caveats for a real implementation

- **The same place can have several area IDs.** Elwynn Forest has IDs 12, 16118, 16147 and 16510, with children like Goldshire and Eastvale repeated, including "Northshire Valley - Camelot". Group by resolved local name, or merge IDs at build time.
- **Overlay rectangles are coarse.** They overlap and cover 54% of sub-zones. Capital cities have none, so a quest there needs another answer.
- **Zones overlap at borders.** This run put 86 quests under Stormwind within Elwynn's list, and 15 under Ratchet within Durotar's. The cause wasn't traced. The real build should start from QuestieDB's area-keyed spawns and the quest's own zone.
- **Forever moved some map frames.** QuestieDB converted Mulgore, Eastern Plaguelands, Redridge and Stormwind from Era coordinates. Never mix Era and Forever coordinates.
- **New quests are the weak spot.** Location data exists for about 70%, and Questie's maintainers warn that wrong data "will stay like this for quite some time". Live capture matters most there.
- **Item objectives need another step.** Half of Era quests (2,132) have item objectives, and 1,581 of those resolve to a drop or vendor source. Zmap's objective list already includes droppers for many. Items carried from the quest giver have no source, which is right: those are deliveries.
- **Licensing.** Bundling a table derived from QuestieDB would most likely mean releasing the addon under GPL-3.0. That seems fine for a free addon, but it's your call.
- **Size is small.** About 4,900 quest-to-area pairs is tens of KB in Lua. QuestieDB's own measurements show this kind of table loads in milliseconds on Era.
- **The data will drift.** A build script should regenerate the table after each patch and report what changed.

## Sources

- Local: `reference/QuestieDB/docs/forever-data.md`, `reference/Questie/docs/forever-development.md`, `reference/Questie/FOREVER_WORK_LEFT_TO_DO.md`
- [Does Questie work in WoW Forever?](https://realmfirst.net/news/wow-forever-does-questie-work/), Realm First
- [Questie in WoW Forever](https://wowforevertierlist.com/addons/questie), WoW Forever Tier List
- [wago.tools DB2 browser](https://wago.tools/db2)
- Search results only: [Everloot](https://github.com/Everloot/everloot/releases/tag/addon-v0.3.3), [UlDungeonCompanion](https://www.curseforge.com/wow/addons/uldungeoncompanion), [EldoUI](https://github.com/Eldodeldo/EldoUI/wiki/journal-data-reports.md), [AEGIS: Pathfinder](https://www.curseforge.com/wow/addons/aegis-pathfinder)
