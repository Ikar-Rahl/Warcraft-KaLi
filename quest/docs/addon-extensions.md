# Letting other addons add to the tracker

Researched 2026-11-06 against build 1.60.1.70790 and the addons installed on Ikar's client. Nothing here has been built or run in-game.

## Summary

Yes, it's possible, in two layers. Neither asks anything of the other addon or names one:

1. **Blizzard's own extension points** keep working, because the addon uses the same names.
2. **Existing hooks on Blizzard's tracker** are fired again for the addon's rows. This is how Spoken's button should appear with no change on its side.

Layer 2 is new as far as I can find, so it needs an in-game test. **No public API,** Ikar's ruling on 2026-11-07: it was never needed, so it's dropped from the plan.

## What Spoken does

From `Spoken_Quests/Compatibility.lua`:

```lua
hooksecurefunc(module, "AddBlock", function(_, block) Dress(block) end)   -- QuestObjectiveTracker and Campaign
```

`Dress` reads `block.id` as the quest, creates one 14 by 14 button as a child of the block, anchors it to the block's top right, and rebinds it whenever the block shows another quest. A second routine walks `module.usedBlocks` to catch blocks drawn before it loaded.

After a rewrite, Blizzard's blocks are hidden, so that button would exist but never show.

**Ikar's ruling, 2026-11-06: Spoken's Play button must stay.** It keeps the far right of the row, where it is today, with item, eye and share buttons to its left. It only narrows the title, because it's only as tall as the title's first line. On Blizzard's tracker it sits over a quest's item button, so the addon's rows improve on that.

## Layer 1: Blizzard's extension points

| Point | What it gives | How the addon keeps it |
| --- | --- | --- |
| `Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", fn)` | Entries in a quest's right-click menu | Its menu uses the same tag. Blizzard passes no context here, so the addon also passes `{ questID = id }`, which is a small improvement |
| `Menu.ModifyMenu` with `MENU_ACHIEVEMENT_TRACKER`, `MENU_PROFESSIONS_RECIPE_TRACKER`, `MENU_BONUS_OBJECTIVE_TRACKER`, `MENU_OBJECTIVE_TRACKER`, `MENU_MONTHLY_ACTVITIES_TRACKER` | The same, for other sections | Same tags |
| `EventRegistry` event `OnQuestBlockHeader.OnEnter` | Hover on a quest, for tooltip lines | Fired with the row, quest ID and in-group flag |
| `EventRegistry` events `Scenario.ObjectTracker_OnEnter`, `BonusObjectiveBlock.QuestRewardTooltipShown` | Hover on those | Fired the same way |
| `ObjectiveTrackerContainerMixin.AddTopPaddingProvider` | Room above the tracker, as the timer panel uses | The host keeps it, and the addon reads the result |
| `ObjectiveTrackerManager:SetModuleContainer` | A whole section of an addon's own | Stays visible under the safety net in [tracker-parity.md](tracker-parity.md) |

No installed addon adds to the tracker's menu today. AutoBiographer, Wayfinder and FieldJournal use `Menu.ModifyMenu` on other tags, which the rewrite doesn't touch.

## Layer 2: firing existing hooks for the addon's rows

`hooksecurefunc` replaces `QuestObjectiveTracker.AddBlock` with a wrapper that calls the original, then each hook. The addon can call that wrapper itself, passing a stand-in for `self`:

```lua
-- Blizzard's AddBlock only uses self, and CanFitBlock = false makes it do nothing else.
local standIn = setmetatable({ CanFitBlock = function() return false end }, { __index = QuestObjectiveTracker })
QuestObjectiveTracker.AddBlock(standIn, row)
```

Blizzard's body runs on the stand-in, writing `hasTriedBlocks` and `hasSkippedBlocks` there instead of on the real section. The metatable lets a hook read real values while its writes stay on the stand-in. Then every hook runs with `(standIn, row)`. Spoken's `Dress(row)` works as it does on a real block, because the row has `id` and is a frame.

Calling the real `QuestObjectiveTracker:AddBlock(row)` isn't an option: it would write `contentsHeight` and `lastBlock` into Blizzard's section and taint its layout.

The addon's part after that:
- **Make room.** It compares the row's children against the ones it created. Anything new and shown goes in the row's right-hand strip and narrows the title. Spoken anchors only once, so this placement holds.
- **Repeat at each layout,** because Spoken's own sweep only visits Blizzard's blocks. A setting change or a late-loading voice pack shows on the next layout.
- **Closed groups have no rows.** A quest's button appears when its group opens, on the next layout.

**Limits:**
- It only reaches hooks on `AddBlock`. Hooks on other methods keep firing on Blizzard's hidden blocks, with no visible result.
- It relies on hooks reading fields that rows also have. Rows use Blizzard's templates and field names to cover that.
- This is untested, so it's in the first in-game test.

**If it fails,** in order of preference:
1. Move unknown children from Blizzard's hidden blocks to the matching rows. This also names no addon, but it reparents another addon's frames.
2. A small adapter for Spoken. You'd rather avoid this, so it's last.

## Installed addons that touch the tracker

| Addon | What it does | After the rewrite | Action |
| --- | --- | --- | --- |
| **Spoken** | Hooks `AddBlock` on Quests and Campaign, walks `usedBlocks`, adds a Play button | Button on the addon's rows through layer 2 | Test |
| **ForeverQuestTint** | Marks quests that weren't in original Classic. Scans under `ObjectiveTrackerFrame` for font strings matching quest titles and adds its ∞ icon to their text with `SetText`, which can add a wrapped line. It can also recolour objectives and draw a 14 by 14 logo as a texture at the block's top right, both off by default. Hooks `Update` on the host and sections | Still scans, and rows sit under the host with the same text, so it should find them, but only while Blizzard shows the host: it doesn't scan a hidden host, and Blizzard hides it whenever its own sections are empty, which with nothing tracked moves the rows to `UIParent` (found 2026-11-09, Ikar saw no ∞ with empty groups; tracking a quest brought it back, and Ikar's ruling the same day is to leave it at that for now). Once it has marked a row's title, it hooks that text and marks it again on every redraw, host shown or not. Row height has to come from the text after it's marked. It also marks the grey line a moved quest leaves, which has the same title. The logo is a texture, so "make room" wouldn't see it, and it would overlap the far right if turned on | Tested in game on 2026-11-09: the ∞ shows once a quest is tracked |
| **DynamicCam** (`UiHideModule`, `LibHideUI`), **LoreForever** (`Screen.lua`) | Fade or hide `ObjectiveTrackerFrame` by name | Rows follow the host. Item buttons aren't its children, so they follow through hooks on its alpha and visibility, and in combat can only fade | Test once |
| **DialogueUI** | Calls `RemoveAutoQuestPopUp`, and flips a quest's watch off and on, or on and off, in one call, and toggles super-tracking, so Blizzard refreshes | API calls only. The rows react to the same events, and read the tracked list only on the next frame, so the flip doesn't move a quest in or out of a group | Test |
| **Auctionator** | Parents a search button to `ProfessionsRecipeTracker.Header` | That header is parked once recipes are rewritten, so the button would vanish | Move unknown children of a parked section header to the addon's header. Generic, and test it |
| **QuestSections Forever** | Post-hooks the section's `Update`, moves blocks, changes heights, calls `MarkDirty` | Same job, working on hidden frames. Harmless but pointless, and its `MarkDirty` calls add work | Tell the player once that it's redundant. Don't disable it for them |
| **Zmap** | Its quest panel shows and toggles the game's tracked list | Still works, and now moves quests in and out of the player's groups, because being in a group is what tracked means | Test |
| **LoreForever** | `Strip.lua` and `Journey.lua` read the tracked list, the first entry being the current quest | Keeps reading it. The list now holds what's in the player's groups, up to the game's limit of 25 | None |

**No options for Spoken or Forever Quest Tint,** following Ikar's question on 2026-11-06. Neither needs integrating by name: Forever Quest Tint finds the rows itself, and Spoken's hook is fired generically through layer 2. Each has its own setting to turn its mark off. If layer 2 fails in-game and Spoken needs an adapter, that adapter gets an option here.

## Sources

- Local, in the game's `Interface\AddOns`: `Spoken_Quests/Compatibility.lua`, `QuestOverlayUI.lua`, `Utils.lua`, `UI/DialogueUIBridge.lua`, `Baganator/API/Main.lua`, `DialogueUI/Code/SupportedAddOns/VoiceoverPublic.lua`, `DialogueUI/API.lua`, `Auctionator/Source_Mainline/CraftingInfo/ObjectiveTracker.lua`, `ForeverQuestTint/ForeverQuestTint.lua`, `QuestSectionsForever/QuestSectionsForever.lua`, `DynamicCam/UiHideModule.lua`, `LoreForever/Screen.lua`
- Local, in `reference/wow-ui-source`: `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua`, `Blizzard_Menu/Menu.lua`, `Blizzard_Menu/11_0_0_MenuImplementationGuide.lua`
