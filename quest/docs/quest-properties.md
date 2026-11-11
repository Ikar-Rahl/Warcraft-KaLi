# Quest classifications, markers and automatic groups

Researched 2026-11-06 against build 1.60.1.70790. Nothing here has run in-game. Reproduce the counts with `python -I quest/tools/research/quest_traits_test.py` and `quest_categories_test.py`. They cover the 4,244 vanilla quests in QuestieDB. New Forever quests aren't in that table, so they aren't measured.

## What the game already does

Forever deliberately shows quest type as text. Its override file says: "Camelot conveys the quest type as text only, so drop the icon markup." A native tracker row looks like this:

```text
[11+] On recherche : "Lardeur" (Élite)
```

| Part | Source |
| --- | --- |
| `[12+]` | `C_QuestLog.GetQuestDifficultyLevel`, with `+` from `C_QuestLog.IsEliteQuest` |
| Colour | `C_PlayerInfo.GetContentDifficultyQuestForPlayer`, if `showQuestDifficultyColor` is on |
| `(Élite)` | `QuestUtilsOverrides.GetQuestTagText`: Élite, Donjon, JcJ or Raid, from the tag ID |

The native tracker shows nothing for daily, weekly, group size, class or party members. The native quest log does add the number of nearby party members on the quest, as `[2]`.

## The complete list

Every way the game classifies a quest. Column meanings:
- **Shown:** Row means visible at a glance, subject to [Which markers show](#which-markers-show). Hover means in the row's tooltip.
- **Filter:** the category in [filter-search.md](filter-search.md). The filter only offers values a quest in the log actually has, so listing everything costs nothing on Forever.
- **Forever:** what the static data says. "Unknown" means the first in-game check prints it for the player's log.

Icons are Blizzard's own art from `Constants.lua` and `AtlasInfo.lua`, one build behind. Forever hides them, so whether each exists on this client needs a check with `C_Texture.GetAtlasInfo`.

### Tags

`C_QuestLog.GetQuestTagInfo(questID).tagID`. This is the game's main type. The name comes from the client's `QuestInfo` table, which has 7 rows, so these are the only tags Forever's data defines.

| ID | `Enum.QuestTag` name | `QuestInfo` name, French | Native row text | Icon | Shown | Filter |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `Group` | **Élite** | (Élite) | `questlog-questtypeicon-group` | Row: `+` in the level | Type |
| 21 | None | Vie | None | None | Row, if it proves to mean class | Type |
| 41 | `PvP` | JcJ | (JcJ) | `questlog-questtypeicon-pvp` | Row | Type |
| 62 | `Raid` | Raid | (Raid) | `questlog-questtypeicon-raid` | Row | Type |
| 81 | `Dungeon` | Donjon | (Donjon) | `questlog-questtypeicon-dungeon` | Row | Type |
| 82 | None | Événement mondial | None | None | Row | Type |
| 83 | `Legendary` | Légendaire | None | `questlog-questtypeicon-legendary` | Row | Type |

In `Enum.QuestTag` but with no `QuestInfo` row here, so they shouldn't occur: `Heroic` 85, `Raid10` 88, `Raid25` 89, `Scenario` 98, `Account` 102, `CombatAlly` 266, `Delve` 288.

The `Group` name is misleading. `Enum.QuestTag.Group` is 1, but on this client's `QuestInfo` table and in `QUEST_INFO_ELITE_ID`, tag 1 means Elite. Group size comes from `suggestedGroup`, never from the tag. Questie calls tag 21 Class, while the client's table calls it "Vie". That's a quick in-game check.

`QuestTagInfo` also has `tagName`, `worldQuestType`, `quality`, `tradeskillLineID`, `isElite` and `displayExpiration`.

### Classification

`C_QuestInfoSystem.GetQuestClassification(questID)`, also `info.questClassification`. A second, newer system that drives the map button's art.

| Value | Name | French | Icon | Forever | Shown | Filter |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | `Important` | Important | `importantavailablequesticon` | Unknown | Row | Classification |
| 1 | `Legendary` | Légendaire | `legendaryavailablequesticon` | Unknown | Row, shared with tag 83 | Classification |
| 2 | `Campaign` | Campagne | `CampaignAvailableQuestIcon` | Unknown. Own section | Section | Classification |
| 3 | `Calling` | Appel | `CampaignAvailableDailyQuestIcon` | Unknown | Row | Classification |
| 4 | `Meta` | Méta | `Wrapperavailablequesticon` | Unknown | Row | Classification |
| 5 | `Recurring` | Répétable | `Recurringavailablequesticon` | Unknown | Row, shared with repeatable | Classification |
| 6 | `Questline` | Suite de quêtes | `questlog-storylineicon` | `QuestLine` has 3 rows and 22 linked quests, so rare | Hover | Histoire |
| 7 | `Normal` | None | None | Default | None | Not offered |
| 8 | `BonusObjective` | None | None | Unknown | Own section | Classification |
| 9 | `Threat` | None | None | Unknown | Own section | Classification |
| 10 | `WorldQuest` | None | None | Unknown | Own section | Classification |

### Repetition

| Source | Values | Forever | Shown | Filter |
| --- | --- | --- | --- | --- |
| `info.frequency`, `Enum.QuestFrequency` | `Default` 0, `Daily` 1 "Quêtes journalières", `Weekly` 2 "Hebdomadaire", `ResetByScheduler` 3 | None of the 4,244 vanilla quests is flagged daily or weekly. New quests unknown | Row: `questlog-questtypeicon-daily`, `-weekly` | Répétition |
| `IsRepeatableQuest` | True or false | 609 of 4,244 (14%) | Row: `QuestRepeatableTurnin` | Répétition |
| `IsQuestReplayable`, `IsQuestReplayedRecently` | True or false | Unknown | Hover | Répétition |
| `Enum.QuestRepeatability` | `None`, `Daily`, `Weekly`, `Turnin`, `World` | Only defined. No documented call returns it | None | None |
| `Enum.CombinedQuestLogStatus` | `Available`, `Complete`, `CompleteDaily`, `CompleteWeekly`, `CompleteMonthly`, `CompleteYearly`, `CompleteGameReset`, `Reset` | For account status | None | None |

### State

| Property | API | Shown | Filter |
| --- | --- | --- | --- |
| Complete | `IsComplete`, `ReadyForTurnIn` | Row: the "À rendre" line and the map button's style, as native | État |
| Failed | `IsFailed` | Row: the word, as native | État |
| Timed | `GetTimeAllowed`, `GetQuestTimers`, `ShouldDisplayTimeRemaining` | Row: clock icon `questlog-questtypeicon-clockyellow`. Blizzard's timer panel stays | État |
| Needs money | `GetRequiredMoney` | Row: money line, as native | État |
| Sequenced | `IsQuestSequenced` | Row: next objective appears, as native | État |
| Auto-complete | `info.isAutoComplete` | Row: "click to complete", as native | État |
| Has a usable item | `GetQuestLogSpecialItemInfo` | Row: item button, as native | État |
| On the game's tracked list | `GetQuestWatchType`: `Automatic`, `Manual` | Being in one of the player's groups. See [organiser-design.md](organiser-design.md#tracked-means-in-a-group) | None |
| Disabled | `IsQuestDisabledForSession` | Hidden, as native | None |
| Hidden | `info.isHidden` | Hidden, as native | None |
| Done before | `IsQuestFlaggedCompleted`, `IsQuestFlaggedCompletedOnAccount` | None | None |

### Difficulty

`C_PlayerInfo.GetContentDifficultyQuestForPlayer`, `Enum.RelativeContentDifficulty`: `Trivial`, `Easy`, `Fair`, `Difficult`, `Impossible`. Colour from `GetDifficultyColor`. Shown on the row by the title's colour, as native. Filter: Difficulté. `IsQuestTrivial` is the same idea as a yes or no. Level comes from `difficultyLevel`, `level` and `isScaling`.

### Story

| Property | API | Forever | Shown | Filter |
| --- | --- | --- | --- | --- |
| Story | `info.isStory`, `IsStoryQuest`. Icon `questlog-questtypeicon-story` | Unknown | Hover | Histoire |
| Storyline | `C_QuestLine.GetQuestLineInfo`, classification above | Rare | Hover | Histoire |
| Breadcrumb | `IsBreadcrumbQuest` | Undocumented | Hover | Histoire |
| Label | `QuestLabel` table | 2 rows, one label, meaning unknown | None | None |
| Details theme | `GetQuestDetailsTheme` | No quest has one (0 of 6,616 in `QuestV2`) | None | None |

### Account and faction

| Property | API | Shown | Filter |
| --- | --- | --- | --- |
| Account-wide | `IsAccountQuest`, `ACCOUNT_QUEST_LABEL` "Compte", icon `questlog-questtypeicon-account` | Hover | Compte et faction |
| Faction | `GetQuestFactionGroup`, icons `questlog-questtypeicon-alliance`, `-horde` | Hover | Compte et faction |

### Group play

| Property | API | Shown | Filter |
| --- | --- | --- | --- |
| Suggested group size | `info.suggestedGroup`, `GetSuggestedGroupSize`. `QUEST_SUGGESTED_GROUP_NUM_TAG` "Groupe : %d". Icon `questlog-questtypeicon-group` | Row, with the number | Groupe |
| Party members on it | `QuestUtils_GetNumPartyMembersOnQuest`, `IsUnitOnQuest` | Row: `[2]`, as in the native log | Groupe de joueurs |
| Their progress | `GameTooltip:SetQuestPartyProgress` | Hover, as native | None |
| Shareable | `IsPushableQuest` | **No marker.** A quick share button shows when someone in your party lacks the quest | Groupe de joueurs |
| Can find a group | `QuestUtil.CanCreateQuestGroup` | Row: eye button, as native | Groupe de joueurs |

About 60% of vanilla quests carry the shareable flag (2,565 of 4,244), so marking it on the row would mark most rows and say little. "Shared" on the row therefore means "someone in your party has it too", as Ikar confirmed, alongside the quick share button described in [organiser-design.md](organiser-design.md).

### Place

| Property | API | Shown | Filter |
| --- | --- | --- | --- |
| Log header | `C_QuestLog.GetInfo` walk, `isHeader`, `headerSortKey`, from `QuestSort` and `AreaTable` | Group or zone header | Lieu |
| On this map | `info.isOnMap`, `hasLocalPOI`, `C_QuestLog.IsOnMap` | Area highlight | Lieu |
| In the quest's area | `C_Minimap.IsInsideQuestBlob` | Area highlight | None |

**Log headers carry classification too.** `QuestSort` has 39 rows on this client:
- **Classes:** Démoniste, Guerrier, Chaman, Paladin, Mage, Voleur, Chasseur, Prêtre, Druide. 507 vanilla quests.
- **Professions:** Herboristerie, Pêcheur, Forgeron, Alchimiste, Artisan du cuir, Ingénieur, Tailleur, Cuisinier, Premiers soins. 113 vanilla quests.
- **Seasonal and events:** Saisonnier, Foire de Sombrelune, Guerre d'Ahn'Qiraj, Fête lunaire, Solstice d'été, Invasion, Incursions de cauchemar, Éruption de Blackrock.
- **Others:** Épique, Carte au trésor, Spécial, Légendaire, Réputation, L'Ordre suprême, Campement, Elfe de la nuit.
- **Unused:** 5 rows named "REUSE - old ...".

The seasonal and other categories together hold 363 vanilla quests. How headers map to the tracker's categories is under [How categories are detected](#how-categories-are-detected).

### Retail types

These are listed for completeness. They appear only if a quest has them, and they're handled by their own sections in [tracker-parity.md](tracker-parity.md).

| Source | Values |
| --- | --- |
| `info.isTask`, `isBounty`, `IsQuestTask`, `IsQuestBounty`, `IsQuestInvasion`, `IsWorldQuest`, `IsThreatQuest`, `IsQuestCalling`, `IsMetaQuest`, `IsImportantQuest`, `IsQuestFromContentPush` | True or false |
| `info.worldQuestType`, `Enum.QuestTagType` | `Tag`, `Profession`, `Normal`, `PvP`, `PetBattle`, `Bounty`, `Dungeon`, `Invasion`, `Raid`, `Contribution`, `RatedReward`, `InvasionWrapper`, `FactionAssault`, `Islands`, `Threat`, `CovenantCalling`, `DragonRiderRacing`, `Capstone`, `WorldBoss`, `Prey` |
| `info.quality`, `Enum.WorldQuestQuality` | `Common`, `Rare`, `Epic` |

### Other fields

- **`C_QuestLog.GetInfo` also has:** `useMinimalHeader`, `sortAsNormalQuest`, `isCollapsed`, `startEvent`, `overridesSortOrder`, `readyForTranslation`, `isInternalOnly`, `isAbandonOnDisable`, `campaignID`. They're for layout and not useful as classification.
- **Objectives:** `C_QuestLog.GetQuestObjectives` gives `text`, `type`, `finished`, `numFulfilled`, `numRequired`, `objectiveType`. Blizzard's tracker only tests `type` for `progressbar`, so the in-game check should list the values.
- **Rewards, for the tooltip and search:** `GetQuestLogRewardXP`, `GetQuestLogRewardMoney`, `GetNumQuestLogRewards`, `GetNumQuestLogChoices`, `HasQuestRewardCurrencies`, `HasQuestRewardSpells`.

## Which markers show

**Decided: icons,** with one setting offering Icons, Text or None. The final list and the row's layout are under [Markers](organiser-design.md#markers) in the design.

**The rule: an icon shows only when the row's position and text don't already say it.** A dungeon quest inside its dungeon's group needs no dungeon icon. Measured on vanilla quests with `quest_categories_test.py`, **81.9% of rows show no icon, 18.0% show one, and 0.2% show two.** Repeatable accounts for most of them (609), followed by dungeon (108), raid (39) and PvP (20). Group size and timed quests aren't in the data.

Icons rather than text, because text would match the game but doesn't fit. The tracker is 260 pixels wide, and the French labels are long:

| String | French |
| --- | --- |
| `DAILY` | Quêtes journalières |
| `WEEKLY` | Hebdomadaire |
| `QUEST_SUGGESTED_GROUP_NUM` | Joueurs suggérés [%d] |
| `QUEST_CLASSIFICATION_RECURRING` | Répétable |
| `ELITE`, `CALENDAR_TYPE_DUNGEON`, `CALENDAR_TYPE_PVP` | Élite, Donjon, JcJ |

This departs from Forever's text-only choice, for the width reason above. It needs checking in-game for how small the art stays readable, since the icons' native sizes run from 18 to 32 pixels.

Questie uses level suffixes such as `[24D]` and `[60R]`. They're compact, but the letters come from the local tag name, so they mean less in French.

## Warning: tags may be wrong

Questie keeps a table of quests "for which the GetQuestTagInfo API returns the wrong values". Applied to Era content, which is how Questie treats Forever, it overrides **1,140 of the 4,244 vanilla quests (27%)**:

| Tag | Quests overridden |
| --- | --- |
| Dungeon | 376 |
| Raid | 301 |
| Elite | 246 |
| PvP | 216 |
| World event | 1 |

Questie's maintainers haven't shown these are wrong on Forever specifically. Blizzard's own `(Donjon)` text uses the same call, so a quick look in-game settles it. Questie expects these results:
- "Les masques rouges en soie" (214) and "La Confrérie défias" (166) say Donjon.
- "On recherche : Lardeur" (176) says Élite.

If the tags are wrong on Forever, row markers and the Type filter are affected, but quests are sorted by their header (below), and a player can move any quest by hand.

## How categories are detected

The quest log's own header sorts these quests with no bundled data. The categories themselves and what happens to each case are under [Categories](organiser-design.md#categories) in the design.

| Category | Vanilla quests | Share |
| --- | --- | --- |
| Monde | 2,500 | 58.9% |
| Classe et métiers | 620 | 14.6% |
| Donjons et raids | 558 | 13.1% |
| Évènements | 304 | 7.2% |
| Champs de bataille | 202 | 4.8% |
| Divers | 60 | 1.4% |

### Class quests

| Measure | Quests |
| --- | --- |
| Class-restricted | 804 |
| Under their class's header | **507 (63%)** |
| Under an instance's header | 217 (27%) |
| Under a zone | 74 (9%) |
| Under another category | 6 (1%) |
| Under a class header with no class restriction | 0 |

So the header is always right when it says "class". The ones under an instance are in a sensible place already, such as class quests for raid items, which leaves 74 that a player might expect under their class.

**The header's name must be compared carefully.** `QuestSort` uses the masculine form on this French client, while `UnitClass` follows the character's gender:

| Class | Log header | Female character's class |
| --- | --- | --- |
| Warrior | Guerrier | Guerrière |
| Hunter | Chasseur | Chasseresse |
| Rogue | Voleur | Voleuse |
| Priest | Prêtre | Prêtresse |
| Shaman | Chaman | Chamane |
| Druid | Druide | Druidesse |

Paladin, Mage and Warlock are the same in both. QuestSections Forever compares the header with `UnitClass`, so on a French female character of those six classes, its class section should fail. The correct comparison is `LOCALIZED_CLASS_NAMES_MALE[classFile]`, which Blizzard's source provides.

The 74 in zones might carry tag 21. If they do, it closes the gap with no data.

### Profession quests

141 vanilla quests need a profession skill. All 113 under a profession's header have that requirement, so that header is always right. The others sit under a zone (25), an event (2) or an instance (1).

`QuestSort` names people rather than crafts: "Forgeron", not "Forge". They therefore won't match `C_TradeSkillUI` names, and no API returns them, so recognising these headers takes a small table per client language from Blizzard's `QuestSort`, unless `headerSortKey` turns out to hold the ID.

### Dungeon and raid quests

| Measure | Quests |
| --- | --- |
| Under an instance's header | 558 |
| Of those, also tagged Dungeon or Raid in Questie's table | 530 |
| Tagged Dungeon or Raid, but under another header | 147 |
| Both signals together | **705** |
| Caught by the header alone | **79%** |

The header finds about four in five, with no dependence on the tags. **The game doesn't say which dungeon the other 147 belong to,** so they can't join a dungeon's group. They stay under their own header, with a dungeon or raid marker: Monde 107, Classe et métiers 32, Divers 7, Évènements 1. They're often lead-ins, such as "The Test of Righteousness" under Paladin.

These quests use 26 instance headers, and I checked by hand that all are real dungeons or raids, from The Deadmines to Naxxramas. Recognising a header therefore takes a short list of area IDs, translated live by `C_Map.GetAreaInfo`. Blizzard's `AreaTable` and `Map` supply them, so no QuestieDB data is needed.

The list has to be chosen by hand rather than queried, for two reasons:
- A dungeon's header can use an outdoor area ID, as Uldaman and Razorfen Kraul do.
- 72 top-level areas sit on instance maps, including instanced copies of ordinary zones.

**One group per dungeon, by Ikar's decision,** since mixing dungeons' quests is worse than a few short groups. The group's name is the log's header, and the rows drop the now-redundant `(Donjon)`:

```text
- Donjons et raids                       0/3
    - Les Mortemines                     0/2
        [17] Les masques rouges en soie
        [22] La Confrérie défias
    - Cavernes des lamentations          0/1
        [17] Les peaux communes
```

A manual move into one of the player's groups always wins and stays.

## Sources

- Local: `Blizzard_FrameXMLUtil/Camelot/QuestUtilsOverrides.lua`, `Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua`, `Blizzard_FrameXMLBase/Constants.lua`, `QuestLogDocumentation.lua`, `QuestConstantsDocumentation.lua`, `QuestInfoSharedDocumentation.lua`, `docs/quest-api-inventory.md`
- Local: `reference/db2/1.60.1.70790/QuestInfo*.csv`, `QuestSort*.csv`, `QuestLine.csv`, `QuestLineXQuest.csv`, `QuestLabel.csv`, `QuestV2.csv`, `ChrClasses*.csv`, `Map.csv`, `AreaTable*.csv`
- Local: `reference/Questie/Database/Corrections/questTagInfoCorrections.lua`, `reference/QuestieDB/data/Forever/foreverQuestDB.lua`
- Local: `QuestSectionsForever.lua` in the game's `Interface\AddOns`
- `reference/BlizzardInterfaceResources/Resources/GlobalStrings/frFR.lua`, `AtlasInfo.lua`, `LuaEnum.lua`, one build behind
