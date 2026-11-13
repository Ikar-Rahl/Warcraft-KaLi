# Rewriting the objective tracker

Audit of `reference/wow-ui-source/Interface/AddOns/Blizzard_ObjectiveTracker` for build 1.60.1.70790. Ikar's decision, 2026-11-06: rewrite the whole tracker and transpose every Blizzard feature. Nothing here has been built or run in-game.

## Summary

- The addon draws every title, header and row itself. The list below has 188 numbered features and serves as the checklist.
- `ObjectiveTrackerFrame` stays as an invisible host, because Edit Mode, the timer panel and other addons depend on it. Only its contents are replaced.
- Blizzard's hidden code keeps running, because other Blizzard code calls it directly. The addon writes nothing into its Lua tables.
- Quests, recipes and achievements have evidence of being live on Forever. The rest need one in-game check, listed under [Which sections can fill on Forever](#which-sections-can-fill-on-forever).

Ikar's decisions that shape the list, 2026-11-06:
- **Forever only:** a section gets code only if it can hold something on Forever.
- **Tracked means in a group:** every quest in the log appears, in the player's groups if it's tracked and otherwise under Journal, in categories and groups that start collapsed. Opening a group shows its quests with their objectives, as Blizzard's tracker does. Rows marked **Changed** below differ from Blizzard because of this. See [organiser-design.md](organiser-design.md#tracked-means-in-a-group).
- **Combat lock:** opening, closing and scrolling lock when combat starts, and the player can unlock them for that fight. See [Combat](organiser-design.md#combat).
- **No gamepad for now.**

## What stays Blizzard's

| Kept | Why |
| --- | --- |
| The host frame, `ObjectiveTrackerFrame` | It stacks with other right-side frames through `RightManagedFrameTemplate`, and the addon's frame stands on it until moved in Edit Mode. DynamicCam and LoreForever hide it by name, Forever Quest Tint reads the titles in it. Until 2026-11-13 its Edit Mode settings were the tracker's position, height, opacity and text size; since, the tracker is an Edit Mode frame of its own and the host's box is see-through ([organiser-design.md](organiser-design.md#the-trackers-frame-in-edit-mode)) |
| `QuestTimerFrame` | A child of the host. Forever turns off row timers (`CanShowTimerBar` returns false), so this panel is the native look |
| Sorting watches, auto-tracking accepted quests | The host's own `OnEvent` |
| `QuestObjectiveTracker` and the other sections, hidden | `QuestFrame.lua` calls `QuestObjectiveTracker:AddAutoQuestPopUp` directly, and the hidden section adds completion popups on `QUEST_AUTOCOMPLETE` |

## How it works

1. **A root frame, child of the host.** Everything the addon draws hangs from it, so addons that fade, hide or scan `ObjectiveTrackerFrame` still reach it.
2. **Blizzard's contents are parked.** After `ObjectiveTrackerManager:Init` runs, each rewritten section and the host's `Header` get `SetParent(hiddenFrame)`. Blizzard's `Show()` calls then have no visible effect and its layout keeps running. This is a widget call, so no Lua table is written. Questie warns against reparenting protected frames on Forever, so the first test is `IsProtected()` on each. If any is protected, the alternative is `Hide()` with an `OnShow` hook, which is what Questie does.
3. **One post-hook follows Blizzard.** `hooksecurefunc(ObjectiveTrackerFrame, "Update", ...)`. Text size, opacity, Edit Mode moves and the splash screen all pass through it. The hook reads `topModulePadding` and `GetAvailableHeight()`, anchors `NineSlice` to the last row, and asks for a layout.
4. **Own events, one layout per frame.** The events are listed under [Events](#events). The addon never calls `MarkDirty`, `Update` or `QuestLogQuests_Update` on Blizzard's objects.
5. **Blizzard's templates, own pools.** Rows use `ObjectiveTrackerQuestPOIBlockTemplate`, `QuestObjectiveLineTemplate` and the rest, which bring the art, fonts and animations. The block and section mixins' `GetLine`, `FreeLine`, `AddRightEdgeFrame`, `GetPOIButton` and `FreeBlock` reach `ObjectiveTrackerManager:AcquireFrame` and `ReleaseFrame` or a local button pool. Those write into Blizzard's shared pools and would taint them, so the addon overrides them with its own.
6. **Rows look like Blizzard's blocks from outside.** `row.id`, `row.HeaderText`, `row.HeaderButton`, `row.poiButton`, `row.ItemButton`, `row.usedLines` and `row.parentModule` keep their names. See [addon-extensions.md](addon-extensions.md).
7. **Stepping aside instead of a safety net,** Ikar's ruling on 2026-11-07: no Blizzard section is shown under the addon's rows. Blizzard's hidden sections keep laying themselves out, so after each of their updates the addon reads whether one the addon doesn't draw found something to show (`hasContents`, or `hasTriedBlocks` when it had no room). Sections after Blizzard's quests can be left no room and never look, so for world quests, collections, activities and initiatives the addon also asks the game what the section would. While one has contents, the addon gives Blizzard's tracker back, says so at the top of the screen and in chat, and comes back once it's empty; in a fight it waits for the end. `/kq tracker on` keeps the addon's tracker anyway, with a line on top naming what only Blizzard's shows; clicking it switches. Each section seen is kept in `KaLiQuestDevDB.sectionsSeen` with its count, date and zone, and `/kq diag` shows them. `UI/Coverage.lua`.
8. **Failure.** Layout runs in `pcall`. On an error the sections return to the host with `SetParent`, the root hides, and one line says so. Disabling the addon leaves everything as it was.
9. **Frames start without a parent.** `CreateFrame(type, name, nil, template)`, then `SetParent`. `SmartNavigationMixin:SetupFrameHooks` hooks `CreateFrame` and rebuilds a panel's button groups inside the caller. Spoken's source records the result on Forever: tainted groups, then a "blocked from an action" dialog that repeats until the client hangs.
10. **Item buttons sit over the rows, not in them.** Secure buttons go on `UIParent`, placed by position after each layout and scroll step. A secure button inside a row would pass its combat limits to the row, so this keeps rows free to open, close and scroll in combat. See [Combat](organiser-design.md#combat).

**Costs:**
- Blizzard's layout still runs, so that work is done twice. Stopping it (`UnregisterAllEvents` on each section) is a later optimisation if it shows up in a measurement.
- The hidden section plays its own sounds, so the addon must not play them again. They're marked Native in the list.
- New Blizzard tracker features won't appear by themselves. After a patch, diff this folder against this list.

**Alternatives rejected:**

| Approach | Why not |
| --- | --- |
| Hide the host too (Questie) | Loses the timer panel and everything that keys on the host. **This is the fallback** if parking fails, with a home-made timer panel and the root anchored at the host's position |
| `ObjectiveTrackerManager:RemoveAllModules()`, as Blizzard's kiosk build does | Writes `modules` and `canAddModules`. Edit Mode reads those later and would run tainted |
| Register subclassed sections in Blizzard's container | Blizzard's layout then runs on addon data. Questie warns that this layout reads restricted auras and taints |
| `QuestObjectiveTracker:SetCollapsed(true)` (Objectively) | Writes `isCollapsed`, which Blizzard's layout reads |
| Copy Blizzard's files (Kaliel's Tracker) | Goes stale at the next rewrite. The romracer fork of Kaliel's dates from before the current tracker |

## Which sections can fill on Forever

All 11 sections load on this client, because the tracker's TOC has no game-type gate on them. Whether they can hold anything is a separate question.

| Section | French header | Evidence | Plan |
| --- | --- | --- | --- |
| Quests, with popups | Quêtes | Native. Certain | Rewrite first |
| Campaign | Campagne | Same code as quests. `QuestLine` has 3 rows and 22 linked quests. Wago doesn't serve the campaign tables for this build | Comes with the quest code |
| Recipes | Métier | Forever's own `Camelot/Blizzard_ProfessionsCrafting.lua` positions `TrackRecipeCheckbox`. Auctionator adds a button to this section's header | Rewrite |
| Achievements | Hauts faits | `Achievement` has 440 rows. Forever shows them as "Legacy Challenges", which needs renown above 0 to open | Rewrite, after checking tracking works |
| Scenario | Scénario | Unknown. `Blizzard_ChallengesUI` doesn't load on Forever (`standard, mists`), so challenge mode can't | Probe |
| Widgets | The zone's name | Unknown. `C_UIWidgetManager.GetObjectiveTrackerWidgetSetID` | Probe |
| Collections | Collections | Unknown. `C_ContentTracking.GetCollectableSourceTrackingEnabled` | Probe |
| Bonus objectives | Objectifs bonus | Unknown. `GetTasksTable` | Probe |
| World quests | Expéditions | Retail concept, but the same probe | Probe |
| Activities | Journal de voyage | Its window is in `Blizzard_EncounterJournal`, whose TOC lists `standard, classic`, so it doesn't load here | Probably empty. Probe |
| Initiatives | Initiatives | `Blizzard_HousingDashboard` is `standard` only | Probably empty. Probe |

**Decided:** every feature stays on this list, but a section that the probe shows can't fill gets no code until it can. If one ever fills, the addon steps aside for Blizzard's tracker ("How it works" 7).

**More evidence, 2026-11-07:** Forever's own collections window (`Camelot/Blizzard_Wardrobe.lua`) has no way to track an appearance, so Collections can't fill either, like Activities and Initiatives. Forever does load Blizzard's Delves companion window and the Island Expeditions queue, both scenario content, so Scénario may fill. Dun Morogh has an objective-tracker widget set (240), empty when probed.

## Every feature

Plan values:
- **Host:** the host frame keeps doing it.
- **Native:** Blizzard's hidden code keeps doing it.
- **Template:** the addon's own instance of Blizzard's template.
- **Same call:** the addon's code makes the same API call.
- **Own:** the addon's code, same result.
- **Replaced:** deliberately different.

### The tracker frame

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| F1 | Position, dragged in Edit Mode | `EditModeObjectiveTrackerSystemTemplate` | **Changed:** the tracker's own Edit Mode frame, one place per layout, on the host until moved |
| F2 | Height setting, 400 to 1000, away from the default position only. Default 800 | `ShouldShowSetting`, `UpdateHeight` | Host, read with `GetAvailableHeight`. **Added:** the addon's Height option, with the last change winning |
| F3 | At the default position, height follows the parent, minimum 20 | `UpdateHeight` | Host |
| F4 | Stacks with other right-side frames | `RightManagedFrameTemplate`, `ManageFramePositions` | Host |
| F5 | Background opacity, default 0 | `SetOpacity`, `NineSlice` | **Changed:** the addon's own background, 5 left of the rows where Blizzard's starts 30 left, with its own opacity in the tracker's dialog, Blizzard's until set. See [Options](organiser-design.md#options) |
| F6 | Text size 12 to 20, headers 2 larger | `SetTextSize`, `ObjectiveTrackerLineFont`, `ObjectiveTrackerHeaderFont` | **Changed:** the addon's own font objects on Blizzard's families at 12 and 14; the zoom sizes the tracker, and Edit Mode's text size no longer applies (2026-11-13) |
| F7 | Strata LOW | XML | Host |
| F8 | Title "Tous les objectifs" | `TRACKER_ALL_OBJECTIVES`, `ObjectiveTrackerContainerHeaderTemplate` | Template |
| F9 | Collapse-all button, four atlases, standard sound | `ui-questtrackerbutton-collapse-all`, `expand-all`, pressed versions | Template. The addon saves the state, Blizzard doesn't. **Changed:** locked in combat until the player unlocks |
| F10 | Collapsing leaves only the title | `isCollapsed` | Own |
| F11 | Hidden when nothing shows, except in Edit Mode | `Update` | **Changed:** Blizzard hides the host when nothing is tracked, but rows no longer depend on that, so the addon keeps it shown while the log has a quest |
| F12 | Title hidden if game rule `ObjectiveTrackerDisabled` is active | `ShouldShowHeader` | Same call |
| F13 | Top room: 38, plus anything registered as a provider | `UpdateTopPadding`, `AddTopPaddingProvider` | Read `topModulePadding`. **Changed:** Suivi starts at 28, inside the title's height, unless the search box, its status or a popup shows. See [Details](organiser-design.md#details) |
| F14 | Title moves down under providers, such as the timer panel | `UpdateHeaderPosition` | Own |
| F15 | Section order: Scenario, Widgets, Campaign, Quests, Collections, Achievements, Activities, Initiatives, Recipes, Bonus, World quests | `ObjectiveTrackerManager:Init` | Same order |
| F16 | Scenario and Bonus claim height first, wherever they sit | `hasDisplayPriority` | Own |
| F17 | Once a section is cut off, later ones get no room | `IsTruncated` | Own |
| F18 | 10 between sections, 10 under the last | `moduleSpacing`, `bottomModulePadding` | Same values |
| F19 | One layout per frame, however many events | `DirtiableMixin` | Own |
| F20 | Layout again on resize | `OnSizeChanged` | Follows the post-hook |
| F21 | Tracked list re-sorted on zone change | `C_QuestLog.SortQuestWatches` | Native. **Changed:** no effect on rows |
| F22 | Accepted quests tracked automatically, if `autoQuestWatch` is on and under the limit. `QuestMapFrame` also tracks a quest whose objectives move, on `QUEST_WATCH_UPDATE` | `QUEST_ACCEPTED`, `QuestMapFrame.lua:584` | Native. **Changed:** the quest joins a group through `QUEST_WATCH_LIST_CHANGED`, and the addon turns `autoQuestWatch` off at install, with an option to turn it back on. See [Options](organiser-design.md#options) |

### Section headers

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| H1 | Title on a bar, 260 by 26, one line, shrinks to fit | `ObjectiveTrackerModuleHeaderTemplate` | Template. **Changed:** quest categories use this bar in place of the single "Quêtes" one |
| H2 | Collapse button, 16 by 16, four atlases, standard sound | `ui-questtrackerbutton-secondary-collapse`, `expand` | Template. State saved. **Changed:** a double arrow at the right of the line, also on groups, in place of this button. See [organiser-design.md](organiser-design.md#details). Locked in combat until the player unlocks |
| H3 | First appearance: bar fades in 0.5 s, button 1 s, glow 0.8 s, shine 0.7 s | `AddAnim` | Template |
| H4 | Shows only with contents. A collapsed section stays if anything could show | `InternalAddBlock` | Own |
| H5 | Spacing: header 25, first row 10 below, indent 20, 10 between rows, 4 between lines | Section settings | Same values |
| H6 | A popup or timed scenario expands the section and the tracker | `ForceExpand` | Own, reading what's waiting. Popups show above the bars, so they don't open a category |

### Which quests appear

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| Q1 | Tracked quests | `GetNumQuestWatches`, `GetQuestIDForQuestWatchIndex` | **Changed:** every quest in the log, from a `C_QuestLog.GetInfo` walk |
| Q2 | Not tasks, bounties or quests disabled for the session | `ShouldDisplayQuest` | Same rules, plus `isHeader` and `isHidden` |
| Q3 | Campaign quests go to their own section | Classification | Same rule |
| Q4 | No quests in arenas | `IsInInstance` | Same call |
| Q5 | Order: callings, then `overridesSortOrder`, then watch order | `CompareQuestWatchInfos` | **Changed:** the player's order in their groups, log order in automatic ones |
| Q6 | At most 25 | `MAX_QUEST_WATCHES` | **Changed:** no limit below the log's 40 |
| Q7 | A row that doesn't fit is cut, along with those after it | `CanFitBlock` | **Changed:** the list scrolls, with the mouse wheel and `MinimalScrollBar`, because the whole log can be taller than the tracker |
| Q8 | A leaving row keeps its place until its animation ends | Cached blocks | Own |

### Quest title

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| T1 | `[level+] Title (Tag)` | `SetQuestTitleLevelAndDifficultyColor`, `QuestUtilsOverrides.GetQuestTagText` | **Changed:** the plain title, with the level and its `+` as a coloured number in a column to its left, and icons instead of `(Tag)`. See [Quest rows](organiser-design.md#quest-rows) |
| T2 | Difficulty colour, on or off | `showQuestDifficultyColor`, `GetContentDifficultyQuestForPlayer` | **Changed:** the same difficulty, as the level number's colour. With the option off, the number takes the title's colour. Titles stay one colour |
| T3 | At most 2 lines | `SetStringText` | Same |
| T4 | Hover brightens the title and its objectives | `UpdateHighlight`, `OBJECTIVE_TRACKER_COLOR` | Same idea, from anywhere on the box |
| T5 | Title narrows for buttons on the right | `rightEdgeOffset` | Own |
| T6 | The click area is the title text only | `HeaderButton` | **Changed:** the whole box, for click, right click and drag, as Ikar ruled |

### Map button

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| P1 | Shown only if `questPOI` is on, follows changes. It's the world map's "quest objectives" filter, and Ikar's screenshots show it off | `CanShowPOIs`, `Blizzard_WorldMapTemplates.lua` | Same CVar |
| P2 | Left of the title, offset -7, 5 | `AddPOIButton` | Same |
| P3 | In-progress and complete styles | `POIButtonUtil.Style` | Template |
| P4 | Focused look follows super-tracking | `SetSelected`, `Supertracking.OnChanged` | Template |
| P5 | Art by classification: legendary, campaign, calling, recurring, important, meta | `POIButton_UpdateQuestInProgressStyle` | Template |
| P6 | A quest theme can replace the art | `GetQuestDetailsTheme` | Template |
| P7 | Click focuses, click again clears, sounds on and off | `POIButtonMixin:OnClick` | Template |
| P8 | With chat open: link. With Shift: untrack | `TryInsertQuestLinkForQuestID`, `CanRemoveQuestWatch` | Template. Untracking takes the quest out of its group |
| P9 | Clicking an untracked quest tracks and focuses it | `AddQuestWatch` | Template, so the quest joins a group. **Changed:** focusing also opens the quest's group and category |
| P10 | Hover highlight. Tooltip while a quest session holds it | `POIButtonHighlightManager`, `QUEST_SESSION_ON_HOLD_TOOLTIP_TITLE` | Template |
| P11 | Pops in with a new row, 0.3 s | `AddAnim` | Template |

### Item button

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| I1 | Shown if the quest has an item, and after completion only if flagged | `QuestUtil.QuestShowsItemByIndex` | Same call |
| I2 | 26 by 26, in a 42 by 42 frame | `UI-QuestTrackerButton-QuestItem-Frame` | Same art on a secure button over the row. See [Risks](#risks) |
| I3 | Icon and charges | `GetQuestLogSpecialItemInfo`, `SetItemButtonCount` | Same call |
| I4 | Cooldown, greyed when unusable | `GetQuestLogSpecialItemCooldown`, `BAG_UPDATE_COOLDOWN` | Same call |
| I5 | Range mark: red, grey or hidden, refreshed on a timer and on target change | `IsQuestLogSpecialItemInRange`, `PLAYER_TARGET_CHANGED` | Same call |
| I6 | A change in charges redraws the row | `OnUpdate` | Own |
| I7 | Tooltip | `SetQuestLogSpecialItem` | Same call |
| I8 | Click uses it. Chat-link click inserts it | `UseQuestLogSpecialItem`, `CHATLINK` | Secure `type=item`. Chat link in `PreClick` |
| I9 | Glows on entering the quest's area, 6 pulses | `PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED`, `IsInsideQuestBlob` | Same event |
| I10 | Sits at the right edge, buttons 2 apart | `AddRightEdgeFrame` | Own. **Changed:** in an unlocked fight, it stays where it was if its row moves |

### Find-group button

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| G1 | Shown if a group can be made for the quest | `QuestUtil.CanCreateQuestGroup` | Same call. **Changed:** an option can turn the button off. See [Options](organiser-design.md#options) |
| G2 | 30 by 30, eye icon, offset 5, 2 | `QuestObjectiveFindGroupButtonTemplate` | Template |
| G3 | Tooltip "Trouver un groupe" | `TOOLTIP_TRACKER_FIND_GROUP_BUTTON` | Template |
| G4 | Click opens the finder | `LFGListUtil_FindQuestGroup` | Template |

### Objective lines

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| L1 | Text without the percentage suffix | `GetQuestLogLeaderBoard(i, index, true)` | Same call |
| L2 | Dash shown, hidden, or hidden and collapsed | `OBJECTIVE_DASH_STYLE_*`, `QUEST_DASH` | Same |
| L3 | Full wrapping, no line limit | `useFullHeight` | Same |
| L4 | Colours: normal, complete, failed, with hover partners | `OBJECTIVE_TRACKER_COLOR` | Same table, read only |
| L5 | Finished: check pops 0.3 s, glow sweeps 0.66 s, turns grey | `ObjectiveTrackerAnimLineTemplate` | Template |
| L6 | Finished objectives stay visible, unless sequenced | `DoQuestObjectives` | Same logic |
| L7 | **Next objective on sequenced quests:** the finished step fades, the next appears only then, with a glow | `IsQuestSequenced`, `QuestObjectiveLineMixin` | Same logic. Sound is Native |
| L8 | An objective that gets undone returns to normal | State `Present` | Same logic |
| L9 | On quest completion, remaining objectives check off, then all fade after 1 s | `Completing`, `Fading`, `FadeOutAnim` | Same logic |
| L10 | Progress bars | `GetQuestProgressBarPercent`, `ObjectiveTrackerProgressBarTemplate` | Template |
| L11 | Money needed: have / need | `requiredMoney`, `GetMoneyString` | Same call |
| L12 | **Next step text**, for the focused quest or the one selected on the map | `GetNextWaypointText`, `WAYPOINT_OBJECTIVE_FORMAT_OPTIONAL` | Same call. May be empty on Forever |
| L13 | Timer bars, white to yellow to red | `AddTimerBar` | Off for quests here (`CanShowTimerBar`). Template for scenario and achievement lines |
| L14 | Links in objective text can be clicked | `OnHyperlinkClick`, `SetItemRef` | Same call |

### Completion

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| C1 | Failed: the word "Echec", in the failed colour | `IsFailed`, `FAILED` | Same call |
| C2 | Auto-complete: "Quête terminée" and "(cliquer pour terminer)" | `isAutoComplete` | Same strings |
| C3 | Completion text, after the next step if focused | `GetQuestLogCompletionText` | Same call |
| C4 | With no completion text: next step, else "À rendre" | `QUEST_WATCH_QUEST_READY` | Same order |
| C5 | Held back until objective animations end | `objectiveCompleting` | Same logic |

### Popups

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| A1 | Read from the game's list, first in the section. If they run out of room, nothing else shows | `GetNumAutoQuestPopUps`, `GetAutoQuestPopUp` | Same call |
| A2 | Added on `QUEST_AUTOCOMPLETE` and by the quest frame | `AddAutoQuestPopUp`, `QuestFrame.lua` | Native |
| A3 | Complete: "Cliquer pour terminer la quête". Offer: "Quête découverte !", "Cliquer pour consulter la quête" | `QUEST_WATCH_POPUP_*` | Template |
| A4 | Hidden while the splash frame shows | `SplashFrame:IsShown` | Same check |
| A5 | 68 high, slides in 0.4 s, then shines | `AutoQuestPopUpBlockTemplate`, `SlideIn` | Template. **Changed:** centred in the panel and scaled with the text, up to the panel's width |
| A6 | Icon: question mark, exclamation, item icon, or campaign badge | `UpdateIcon`, `UpdateExclamationIcon` | Template. The item comes from a Blizzard local, so a re-created offer shows the exclamation |
| A7 | Complete popups flash until handled | `UIFrameFlash` | Template |
| A8 | Click opens the offer or the turn-in, then removes the popup | `ShowQuestOffer`, `ShowQuestComplete`, `RemoveAutoQuestPopUp` | Same call |

### Motion

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| M1 | New row: glow across the title, lines fade in 0.5 s, only when first tracked | `AddAnim`, `SetNeedsFanfare`, `QUEST_WATCH_LIST_CHANGED` | Template. **Changed:** on `QUEST_ACCEPTED`. If the row's parents are closed, the closed header glows once instead |
| M2 | Turn-in: glow 0.51 s, fades 0.33 s, row held until done | `TurnInAnim`, `QUEST_TURNED_IN` | Template |
| M3 | Removal: fades 0.5 s after a delay | `RemoveAnim` | Template |
| M4 | Animations queue rather than overlap | `TryPlayAnim` | Same logic |

### Sound

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| S1 | Collapse and focus | `IG_MAINMENU_OPTION_CHECKBOX_ON`, `OFF` | Template or same call |
| S2 | Next objective appears | `UI_QUEST_ROLLING_FORWARD_01` | Native for quests on the tracked list. **Changed:** own call for the others, checked with `QuestUtils_IsQuestWatched` to avoid playing twice |
| S3 | Popup arrives | `UI_AUTO_QUEST_COMPLETE` | Native, not replayed |

### Mouse and menus

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| K1 | Any click with chat open inserts a quest link, checked first | `ChatFrameUtil.TryInsertQuestLinkForQuestID` | Same call |
| K2 | Modified click untracks | `QUESTWATCHTOGGLE`, `CanRemoveQuestWatch` | Same, taking the quest out of its group. **Changed:** on an untracked quest under Journal, it tracks it |
| K3 | Click on a complete auto-complete quest opens the turn-in | `ShowQuestComplete` | Same call |
| K4 | Otherwise click opens the quest | `QuestMapFrame_OpenToQuestDetails` | Same call. Refused in combat |
| K5 | Right-click menu titled with the quest's name | `MenuUtil.CreateContextMenu`, tag `MENU_QUEST_OBJECTIVE_TRACKER` | Same tag, plus `{questID}` as context |
| K6 | Menu: Focalisation or Supprimer le marquage | `SUPER_TRACK_QUEST`, `C_SuperTrack` | Same |
| K7 | Menu: Ouvrir or Fermer les détails de la quête | `OBJECTIVES_VIEW_IN_QUESTLOG`, `QuestUtil.OpenQuestDetails` | Same |
| K8 | Menu: Ouvrir la carte des quêtes | `OBJECTIVES_SHOW_QUEST_MAP` | Same |
| K9 | Menu: Arrêter le suivi, when allowed | `OBJECTIVES_STOP_TRACKING` | Same, for a quest in a group. **Changed:** a quest under Journal has `TRACK_QUEST`, Suivre quête |
| K10 | Menu: Partage de quête, if shareable and in a group | `IsPushableQuest`, `QuestUtil.ShareQuest` | Same |
| K11 | Menu: Abandon | `QuestMapQuestOptions_AbandonQuest` | Same |
| K12 | Hover in a group: party progress tooltip, left of the row | `SetQuestPartyProgress` | Same call |
| K13 | Hover event other addons can listen to | `OnQuestBlockHeader.OnEnter` | Fire the same event |

### Events

Blizzard's quest section: `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `QUEST_AUTOCOMPLETE`, `SUPER_TRACKING_CHANGED`, `QUEST_TURNED_IN`, `QUEST_POI_UPDATE`, `SUPER_TRACKING_PATH_UPDATED`. Campaign uses the first, second and last of those. The events of other sections are named in their tables. **Changed:** the addon drops `QUEST_WATCH_LIST_CHANGED` and adds `QUEST_ACCEPTED`, `QUEST_REMOVED`, `GROUP_ROSTER_UPDATE` and `UNIT_QUEST_LOG_CHANGED`.

### Campaign

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| CA1 | Quest rows and rules, for classification Campaign | `CampaignQuestObjectiveTrackerMixin` | Same code as quests |
| CA2 | Popups get the campaign badge | `AutoQuest-Badge-Campaign` | Template |

### Scenario

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| SC1 | Section title: scenario name, "Ordalie", "Donjon" or the zone | `LayoutContents` | Same logic |
| SC2 | Stage card: "Phase %d" or "Phase finale", name, art by texture kit, theme colour | `UpdateStageBlock` | Template |
| SC3 | Stage tooltip: name, description, XP, money, plus an event | `Scenario.ObjectTracker_OnEnter` | Same |
| SC4 | Card slides out 0.4 s after 0.8 s, then in. Complete labels | `SlideOutContents`, `STAGE_COMPLETE`, `DUNGEON_COMPLETED` | Own |
| SC5 | Start and stage sounds | `startSoundKitID`, `UI_SCENARIO_STAGE_END` | Native |
| SC6 | Criteria: `x/y text`, nub, check with animation, can be hidden | `C_ScenarioInfo.GetCriteriaInfo`, `SCENARIO_CRITERIA_SHOW_STATE_UPDATE` | Same call |
| SC7 | Weighted progress bar, reward icon, flares | `ScenarioProgressBarTemplate` | Template |
| SC8 | Timers on criteria | `AddTimerBar` | Template |
| SC9 | Scenario spell buttons with cooldowns | `ScenarioSpellFrameTemplate`, `CastSpellByID` | Template. Casting needs a test |
| SC10 | Widget sets above and below, and in place of the stage card | Sets 252 and 514, `widgetSetID` | Own container instances |
| SC11 | Find-group eye | `C_LFGList.CanCreateScenarioGroup` | Template |
| SC12 | Rewards panel on completion | `SCENARIO_COMPLETED`, `ScenarioRewardsFrame` | Native |
| SC13 | Challenge mode block: time, level, affixes, deaths | `ScenarioObjectiveTrackerChallengeModeMixin` | Can't happen here. `Blizzard_ChallengesUI` doesn't load |
| SC14 | Proving grounds block: medal, waves, score, countdown | `ScenarioObjectiveTrackerProvingGroundsMixin` | Probe |
| SC15 | Tiered entrance traits | `C_ScenarioInfo.IsTieredEntranceScenario` | Probe |
| SC16 | Maw buffs | `ShouldShowMawBuffs` | **Never call from addon code.** It reads restricted auras |
| SC17 | Ember Court help tip | `EMBER_COURT_MAP_HELPTIP` | Retail content, no need |

### Widgets

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| W1 | Widget set shown in its own section, titled with the zone | `GetObjectiveTrackerWidgetSetID`, `GetRealZoneText`, `ZONE_CHANGED_NEW_AREA` | Own container instance |
| W2 | Section follows whether any widget shows | `GetNumWidgetsShowing` | Same call |

### Achievements

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| AC1 | Tracked list, minus those you earned. Arena-only list in arenas | `C_ContentTracking.GetTrackedIDs` | Same call. No arena list: this client has no arena map |
| AC2 | Up to 5 unfinished criteria, then "..." | `MAX_CRITERIA_PER_ACHIEVEMENT` | Same |
| AC3 | Progress-bar criteria as text, money included. Meta criteria use the other achievement's name | `GetAchievementCriteriaInfo` | Same logic |
| AC4 | Ineligible criteria use the failed colour | `eligible`, `IsAchievementEligible` | Same call |
| AC5 | Timer bars, including for single-criterion achievements | `TRACKED_ACHIEVEMENT_UPDATE` | Own frame with `ObjectiveTrackerTimerBarTemplate`'s art, size and colours, ticking as its mixin does |
| AC6 | New: animates in. Earned: turn-in animation | `CONTENT_TRACKING_UPDATE`, `ACHIEVEMENT_EARNED` | Own animations with the template's timings: the title glow sweeps in; earned, it sweeps and the entry fades in 0.66 s |
| AC7 | Click opens it, which on Forever is Legacy Challenges. Chat link. Modified click untracks | `AchievementFrame_ToggleAchievementFrame`, `ShowLegacyChallenge` | Same call |
| AC8 | Menu: title, Ouvrir le haut fait, Arrêter le suivi | Tag `MENU_ACHIEVEMENT_TRACKER` | Same tag |

### Collections

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| CO1 | Tracked appearances and decor, if tracking is enabled | `GetCollectableSourceTypes`, `IsContentTrackingEnabled` | Same call |
| CO2 | Objective text, "retrieving", location or route unavailable, next step when focused | `GetObjectiveText`, `GetWaypointText` | Same call |
| CO3 | Map button | `POIButtonOwnerTemplate`, `GetButtonForTrackable` | Own owner |
| CO4 | Collected: check, rewards toast, sound, stops tracking | `TRANSMOG_COLLECTION_SOURCE_ADDED`, `HOUSE_DECOR_ADDED_TO_CHEST` | Same logic |
| CO5 | Click: chat link, untrack, dress up with inspect cursor, achievement, profession, or map | `AdventureObjectiveTrackerMixin` | Same logic |
| CO6 | Menu: title, open journal, stop tracking | Tag `MENU_OBJECTIVE_TRACKER` | Same tag |

### Activities

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| MA1 | Tracked activities, with unfinished requirements and no dash | `C_PerksActivities.GetTrackedPerksActivities` | Same call |
| MA2 | Completed: sound and turn-in animation | `PERKS_ACTIVITY_COMPLETED` | Template |
| MA3 | Click opens it. Chat link. Modified click untracks | `MonthlyActivitiesFrame_OpenFrameToActivity` | Same call |
| MA4 | Menu: title, open, stop tracking | Tag `MENU_MONTHLY_ACTVITIES_TRACKER` | Same tag |

### Initiatives

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| IN1 | Tracked tasks and unfinished requirements. Asks for data on zone change | `C_NeighborhoodInitiative` | Same call |
| IN2 | Click opens it. Chat link. Modified click untracks | `HousingFramesUtil.OpenFrameToTaskID` | Same call |
| IN3 | Menu: title, open, stop tracking | Same tag as activities, in Blizzard's code | Same tag |

### Recipes

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| RE1 | Tracked recipes, then recrafts, with a recraft title | `GetRecipesTracked`, `PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER` | Same call |
| RE2 | Waits for item data before drawing | `ContinuableContainer` | Same |
| RE3 | Required reagents only, modifying ones first, `have/need name`, or a range | `ProfessionsUtil`, `PROFESSIONS_TRACKER_REAGENT_FORMAT` | Same call |
| RE4 | Reagent met: check, grey, no dash | `ui-questtracker-tracker-check` | Same |
| RE5 | Refreshes on bags and currency | `BAG_UPDATE_DELAYED`, `CURRENCY_DISPLAY_UPDATE`, `TRACKED_RECIPE_UPDATE` | Same events |
| RE6 | Click opens the recipe or inspects it. Chat link. Modified click untracks | `C_TradeSkillUI.OpenRecipe`, `RECIPEWATCHTOGGLE` | Same call |
| RE7 | Menu: view recipe, untrack | Tag `MENU_PROFESSIONS_RECIPE_TRACKER` | Same tag. Blizzard's "view" passes an undefined `recipeID`, so use the right variable |

### Bonus objectives

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| BO1 | Title "Objectifs bonus", or "Objectifs" if flagged | `displayAsObjective` | Same |
| BO2 | Tasks for the area you're in | `GetTasksTable`, `GetTaskInfo` | Same call |
| BO3 | Scenario bonus steps, hiding superseded ones | `GetBonusSteps`, `GetSupersededObjectives` | Same logic |
| BO4 | Lines with check, nub or fail icon, timers | `CriteriaInfo` | Same |
| BO5 | Progress bar with reward icon, flares, intro | `BonusTrackerProgressBarTemplate` | Template |
| BO6 | Hover: rewards tooltip, plus an event | `GameTooltip_AddQuestRewardsToTooltip`, `BonusObjectiveBlock.QuestRewardTooltipShown` | Same call |
| BO7 | Completed: rewards toast. Left the area: fades after 3.5 s | `QUEST_TURNED_IN`, `QUEST_REMOVED`, `CRITERIA_COMPLETE` | Same logic |
| BO8 | Threat quests | `IsThreatQuest` | Same logic |
| BO9 | Banner on accepting one | `ObjectiveTrackerTopBannerFrame` | Native |
| BO10 | Item and find-group buttons | As quests | As quests |
| BO11 | Click: chat link, map with ping, Shift untracks | `GetQuestZoneID`, `MapCanvas.PingQuestID` | Same call |
| BO12 | Menu: title, stop tracking | Tag `MENU_BONUS_OBJECTIVE_TRACKER` | Same tag |

### World quests

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| WQ1 | Local ones first, then tracked, sorted by area, map, then ID | `GetSortedWorldQuests` | Same logic |
| WQ2 | World quest map button, with elite look | `POIButtonUtil.Style.WorldQuest` | Template |
| WQ3 | Time-left line, refreshed by a timer | `TryAddingExpirationWarningLine` | Same logic |
| WQ4 | Banner and sound on accepting | `WORLD_QUEST_BANNER`, `UI_WORLDQUEST_START` | Native |
| WQ5 | Tooltip with quest type and rewards | `QuestUtils_AddQuestTypeToTooltip` | Same call |

### Toasts and banners

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| BT1 | Rewards toast beside the row, with sound | `ObjectiveTrackerRewardsToastTemplate`, `ShowRewardsToast` | Template, own pool, anchored to the addon's row |
| BT2 | Top banner that slides into the tracker | `ObjectiveTrackerTopBannerMixin` | Native, for its pop. The slide aims at Blizzard's hidden section, so check it looks right |

### Timer panel

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| TP1 | Panel "Temps", 158 wide, 43 plus 16 per timer | `QuestTimerFrame`, `GetQuestTimers` | Host, as Blizzard's own panel. **Changed:** scaled with the text, up to the panel's width, and centred on the rows. Its `TOP` anchor centres it on the host, which is 12 wider than the rows, so it moves 6 left. Built on 2026-11-08 (`Host.PlaceTimer`): scale `min(text / 12, width / 158)`, still 10 under the host's top; Blizzard's size and place come back with Blizzard's tracker. `SetScale` and `SetPoint` on Blizzard's frame need an in-game test |
| TP2 | Pushes the tracker down | `GetTopPadding` | Its height, scaled, plus Blizzard's 18 |

### Gamepad

| ID | Feature | Source | Plan |
| --- | --- | --- | --- |
| GP1 | Moving between rows, with item buttons beside them | `UpdateSmartNavigationOverrides` | See below |
| GP2 | Footer prompts: focus, options, details, untrack, minimize, bind item | `SetUpGamepad` | See below |
| GP3 | Collapse-all hidden in gamepad mode | `InitializeGamepad` | See below |
| GP4 | Menu entry "Partager dans la discussion" | `SHARE_IN_CHAT` | Same call |

**Not for now, by Ikar's decision.** Blizzard wires these to its own rows, and to `QuestObjectiveTracker` by name. Calling the `SmartNavigation_*` functions from addon code is the path Spoken's comment warns about, so this carries real taint risk. Until then, if `InputUtil.IsGamepadUIEnabled()` is true, the addon steps aside and leaves Blizzard's tracker in place, so a gamepad player isn't left with rows they can't reach.

## Risks

1. **Parking the sections.** Whether the host or the sections are protected, and whether anything brings them back. Test first, because the fallback changes the plan.
2. **Host hidden by Blizzard.** `Update` hides the host when no section has contents, which now happens whenever nothing is on the tracked list. The addon re-shows it from an `OnHide` hook. If that's blocked or flickers, the root moves to `UIParent`, anchored to the host, which loses the fading other addons apply.
3. **Scrolling and the combat unlock.** The list needs a scroll frame, which Blizzard's tracker doesn't have. `SetVerticalScroll` carries the same `IsProtectedFunction` flag as `Show` and `SetPoint`, so rows and the scroll frame must stay unprotected. Check `IsProtected()` on them with item buttons on screen, then open, close and scroll in combat.
4. **Item buttons.** Blizzard's is a plain button calling `UseQuestLogSpecialItem`, which is undocumented, so try that first: if it isn't blocked for addons, the combat limits on items disappear. Questie and both Kaliel's forks use `SecureActionButtonTemplate` with `type = item`, and Questie lists it as still needing gameplay checks. A secure button can't be moved in combat, so a quest that gains an item mid-fight shows its button afterwards.
5. **Calls from addon code.** `QuestLogPushQuest`, `QuestMapFrame_OpenToQuestDetails`, `ShowQuestComplete`, `ShowQuestOffer`, `CastSpellByID` and `C_SuperTrack` run tainted when an addon's click calls them. Try each one in and out of combat.
6. **`GetNextWaypointText`.** The game's waypoint tables aren't offered for this build, so "next step" text may be empty on Forever. Sequenced objectives don't depend on it.
7. **Double sound or a missing one.** If Blizzard's hidden layout cuts a tracked quest for lack of height, its sound doesn't play for that quest.
8. **Tracker taint overall.** Check with `/console taintLog 1` after a session with combat, quest items, Edit Mode and popups.

## Sources

- Local, in `Blizzard_ObjectiveTracker`: every `.lua` file, plus `Blizzard_ObjectiveTracker.xml`, `.toc`, `Blizzard_ObjectiveTrackerBlock.xml`, `Blizzard_ObjectiveTrackerShared.xml`, `Blizzard_ObjectiveTrackerAnimTemplates.xml`, `Blizzard_ObjectiveTrackerQuestPOIBlock.xml`, `Blizzard_QuestObjectiveTracker.xml`, `Camelot/Blizzard_QuestObjectiveTrackerOverride.lua`
- Local: `Blizzard_POIButton/POIButton.lua`, `Blizzard_QuestTimer`, `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua`, `Blizzard_UIPanels_Game/Mainline/QuestFrame.lua`, `Blizzard_GamepadSmartNavigation/SmartNavigation.lua`, `Blizzard_Kiosk/Gamescom2025/Game.lua`, `Blizzard_AchievementUI/Camelot/Blizzard_AchievementUI.lua`, `Blizzard_Professions/Camelot/Blizzard_ProfessionsCrafting.lua`, and the TOCs named above
- Local: `reference/Questie/Modules/QuestieCompat.lua`, `reference/Questie/Modules/Tracker/LinePool/TrackerItemButton.lua`, `reference/Objectively/Objectively.lua`, `Spoken_Quests/Utils.lua` in the game's `Interface\AddOns`
- [wago.tools](https://wago.tools/db2) tables for build 1.60.1.70790: `Achievement` (440 rows). `Scenario`, `Campaign` and `QuestV2CliTask` returned errors, so they're unmeasured. `QuestLine` and `QuestLineXQuest` are in `reference/db2/1.60.1.70790`
