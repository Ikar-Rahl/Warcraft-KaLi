# Filter and search

Design, 2026-11-06, for build 1.60.1.70790. **Built on 2026-11-07, tested offline only**: `Core/Filter.lua` and `UI/Search.lua`. The values come from [quest-properties.md](quest-properties.md).

## Summary

- **Filter:** a menu of checkboxes, one for each classification a quest in your log actually has, so retail-only values never clutter it.
- **Search:** text typed by the player, matched anywhere in a quest, ignoring case and accents.
- **Neither moves anything.** They only hide rows. Clearing them restores exactly what was there, and no group changes.
- **Both cover the whole log,** since every quest is now in the tracker.

## What it looks like

Both stay out of sight until used. Two small buttons sit on the title row, and the search box opens below it:

```text
Tous les objectifs             [loupe] [filtre] -
  [masques                               x]
  1 quête affichée sur 9 · Tout effacer
- Donjons et raids                           1
    - Les Mortemines                         1
        [17] Les masques rouges en soie
          - Bandanas de soie rouge : 3/10
```

| Part | Behaviour |
| --- | --- |
| Filter button | Opens a menu using `MenuUtil.CreateContextMenu`, `CreateTitle` and `CreateCheckbox`. Lit while any filter is on |
| Search button | Shows the box and gives it focus. Lit while a search is active |
| Search box | Blizzard's `SearchBoxTemplate`, with its clear button. `SEARCH` ("Recherche") as the hint, because `SEARCH_QUEST_LOG` is too long for 260 pixels |
| Status line | Only while something is hidden: count shown out of total, and `CLEAR_ALL` ("Tout effacer"). This stops a saved filter looking like lost quests |
| No match | `QUEST_LOG_NO_RESULTS`, "Aucun résultat trouvé", as the quest log says |
| Bars and group headers | With no matching quest, hidden. Others show the count of matches |
| Collapsed levels | **Search:** every level holding a match opens while the search is active. **Filter:** levels stay as the player left them, and only the counts change. Neither touches the saved open state |

## Filter

### The rule

Within one category a quest needs **any** ticked value. Across categories it needs **all** of them. A category with nothing ticked doesn't restrict anything. So ticking Donjon and Raid, then À rendre, shows dungeon or raid quests that are ready to turn in.

### Categories

Each entry shows its count, such as `Donjon (3)`. **Values no quest in the log has are left out,** and a category with one value or none is left out too. That lets the code cover every classification in the game with no dead entries on Forever, and a new Forever quest type shows up by itself.

| Category | Values | From |
| --- | --- | --- |
| Type | Élite, Donjon, Raid, JcJ, Légendaire, Événement mondial, tag 21 | `GetQuestTagInfo` tag ID, with instance headers counted as Donjon or Raid |
| Groupe | Quests with a suggested group, listed by size | `suggestedGroup` |
| Répétition | Quotidienne, Hebdomadaire, Programmée, Répétable, Non répétable | `frequency`, `IsRepeatableQuest` |
| État | En cours, À rendre, Échec, Chronométrée, Avec objet, Par étapes | `IsComplete`, `IsFailed`, `GetTimeAllowed`, `GetQuestLogSpecialItemInfo`, `IsQuestSequenced` |
| Difficulté | Grise, Verte, Jaune, Orange, Rouge | `GetContentDifficultyQuestForPlayer` |
| Classification | Each value of `Enum.QuestClassification` except Normal | `GetQuestClassification` |
| Histoire | Histoire, Suite de quêtes | `isStory`, `Questline`. Quête de liaison was planned from `IsBreadcrumbQuest`, which this build doesn't have |
| Compte et faction | Compte, Alliance, Horde | `IsAccountQuest`, `GetQuestFactionGroup` |
| Groupe de joueurs | Un membre l'a aussi, Partageable, Peut trouver un groupe | `QuestUtils_GetNumPartyMembersOnQuest`, `IsPushableQuest`, `CanCreateQuestGroup` |
| Lieu | Sur cette carte, Zone actuelle | `IsOnMap`, the log's header |

French labels come from Blizzard's strings where they exist, and the list in [quest-properties.md](quest-properties.md) names them. Others would be the addon's own text, for the labels shown above in plain French.

### Saving

Filters are saved per character by ID, never by display name, so they survive restarts and language changes. A value that later has no quest stays saved and does nothing.

```lua
filters = { type = { dungeon = true, raid = true }, state = { ready = true } },   -- empty when off
```

## Search

### What it searches

Blizzard's quest log already has a search, `QuestSearcher` in `QuestMapFrame.lua`. It's the model for this one, and it matches title, the objectives paragraph and objective lines. This search covers more:

| Field | Source | In Blizzard's search |
| --- | --- | --- |
| Title | `C_QuestLog.GetTitleForQuestID` | Yes |
| Objectives paragraph | `GetQuestLogQuestText(index)`, second value | Yes |
| Objective lines | `GetQuestLogLeaderBoard` | Yes |
| **Description** | `GetQuestLogQuestText(index)`, first value | No |
| Completion text | `GetQuestLogCompletionText` | No |
| Next step | `GetNextWaypointText` | No |
| Rewards, by name | `GetQuestLogRewardInfo`, `GetQuestLogChoiceInfo`, `C_QuestInfoSystem.GetQuestRewardCurrencies`, `GetQuestRewardSpells` | No |
| Log header, such as the zone | `C_QuestLog.GetInfo` walk | No |
| Group name | Saved layout | No |
| Type words, such as "donjon" or "élite" | The filter's labels | No |
| Level and quest ID | `difficultyLevel`, `questID`, so "17" or "214" finds it | No |

**The quest giver can't be searched natively.** The game has no call for the giver's name in the log beyond `GetQuestLogPortraitGiver`, which is untested here. Spoken gets the giver from its own bundled data.

### Matching

- **Accents and case ignored,** so "elite" finds "Élite". Blizzard's `:lower()` probably doesn't fold accented letters, so "é" wouldn't match "É" in its search. `CaseAccentInsensitiveParse` is in this build's API, and no Blizzard file calls it, so what it returns needs a test. If it falls short, a small French folding table is the fallback.
- **Plain text,** using `find(text, 1, true)` as Blizzard does, so `(` or `%` can't cause an error.
- **Words are separate:** "masque soie" finds quests containing both, in any order.
- **Colour codes, textures and links are stripped** first, with the addon's own patterns, so `|cff` can't match.

### Speed

At most 40 quests, each with a few short strings. Following Blizzard:
- A quest's text is cached the first time it's searched and dropped when the quest leaves the log.
- Each redraw rechecks every quest. At 40 quests that's cheap, so the planned "one more letter only rechecks earlier matches" wasn't needed.
- Objective lines are read fresh each time, finished steps included, so a past step stays findable.
- Rewards that haven't loaded (`HaveQuestRewardData` false) are asked for once with `C_QuestLog.RequestLoadQuestByID`, and added when `QUEST_DATA_LOAD_RESULT` arrives.

## Behaviour rules

| Situation | What happens |
| --- | --- |
| In combat | Filtering and search are refused with `ERR_NOT_IN_COMBAT`, because secure item buttons can't move. Rows already shown keep updating |
| Combat starts during typing | The box keeps its text, and results apply when combat ends |
| Escape, or the clear button | Clears the text, closes the box, gives back the keyboard. In combat the rows wait for the fight's end |
| Typing | Keys go to the box, as with any edit box. Enter keeps the results and gives back the keyboard |
| Restart | Filters stay. Search text doesn't |
| Quest completes while filtered out | Its progress is still counted. Popups and sounds still happen |
| A filtered row and its item button | Both hidden, outside combat |

The category and group structure already sorts by class, profession, dungeon and player's group, so the filter doesn't repeat them. It answers what the tree can't, such as "everything ready to turn in" or "every group quest", across all categories.

## Open question

**Filter by objective kind?** `GetQuestObjectives` gives a type per objective, such as kill or collect. Blizzard's tracker only checks for `progressbar`, so the in-game probe should list the values first.

## Sources

- Local: `Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua`, `Blizzard_APIDocumentationGenerated/LocalizationDocumentation.lua`, `reference/vscode-wow-api/Annotations/Core/Data/Wiki.lua`, `reference/BlizzardInterfaceResources/Resources/GlobalStrings/frFR.lua`, `GlobalAPI.lua`
