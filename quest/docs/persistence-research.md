# Keeping saved data safe: research

Researched 2026-11-06. Sources are at the end. Apart from the installed addons, all of this comes from web pages and forum posts, not from testing.

## Summary

**Saving works on the current client.** The restart bug was real, but it belonged to the beta and a client patch fixed it. On this machine, AutoBiographer keeps its per-character history across full restarts.

Saved data needs no special mechanism here. The addon needs the ordinary practices below, a step-by-step format upgrade and a fixed folder and variable name.

## The Forever bug

| Date (2026) | What happened | Source |
| --- | --- | --- |
| 18 Sep | Reports start. Addon data is written to disk, then not read back after a full restart. The next save overwrites the good file | Blizzard forum thread |
| 18-24 Sep | Build named: 1.60.1.69913. Happens with no addons installed. `/reload` hides it. One poster reports that `LoadSavedVariablesFirst` doesn't help. Workarounds appear: WTFix, ForeverSVFix, delete-and-restore routines | Forum thread, Questie's investigation |
| 25 Sep | "Today's patch seems to have fixed this", not listed in the patch notes. Three other posters confirm that day | Forum thread |
| 25 Sep | ForeverSVFix archived. Its README says "It seems that Blizzard have fixed the issue" | ForeverSVFix |
| 26-27 Sep | WTFix retired: "Current Forever builds now persist addon SavedVariables normally", confirmed by its author in native-client testing on 26 Sep | WTFix |
| 6 Nov | Build 70790. AutoBiographer keeps its data across restarts on this machine | Ikar |

What's still unknown:
- No Blizzard post or patch note confirms the fix, and no source gives the build that fixed it.
- The cause was never published.
- Questie's investigation file still reads as an open problem because it stops at 69913. It's historical now.

One practical lesson survives: **only a full exit and restart tests saving.** `/reload` passed throughout the bug.

## What developers recommend

| Practice | Why | Source |
| --- | --- | --- |
| First touch the variable in your own `ADDON_LOADED` | It's the earliest documented read. `PLAYER_LOGIN` and `VARIABLES_LOADED` aren't needed | Warcraft Wiki |
| Never write the variable or defaults while files load | The saved data replaces them. ForeverSVFix v1.0.1 and AceDB's tutorial both warn about this | Wiki, AceDB, ForeverSVFix |
| Test with `== nil`, never `not x` | `not x` treats a saved `false` as missing and overwrites it | Wiki example, WoWInterface 2007 |
| Fill in nested defaults too | The wiki's simple copy only checks top-level keys, so a key added to a nested table never appears | Wiki example |
| Don't store defaults, or use nil to mean the default | Changing a default later then reaches existing players | Tekkub, WoWInterface 2007 |
| Never replace the whole table | Everything in it is lost | Tekkub, WoWInterface 2007 |
| Save only strings, booleans, numbers and tables | Functions and userdata are dropped. WTFix hit this with an addon storing functions | Wiki, WTFix thread |
| Don't let two saved variables share one table | They come back as separate copies | Wiki |
| Upgrade formats in numbered steps, oldest first | Players can skip versions, so every step stays. Never rewrite a released step | LibSavedVars (an Elder Scrolls Online library, so general advice), AutoBiographer's code |
| Don't edit saved files while the game runs | The client holds them in memory and writes over them on exit | WoWInterface |

Installed addons follow the same pattern. AutoBiographer keeps a `DatabaseVersion` and an ordered list of migrations, running from the saved version plus one. Baganator has a `MigrateSettings` step.

## How the files behave

- **When they're written:** at logout, disconnect, quit and `/reload`. `PLAYER_LOGOUT` is the last event before the write.
- **Crashes:** the wiki says the final commit doesn't happen on a crash or Alt-F4, marked "citation needed", and forum posts agree. Changes since the last write are lost.
- **Locations:** account data is in `WTF\Account\<account>\SavedVariables\<Addon>.lua`, and per-character data in `WTF\Account\<account>\<realm>\<character>\SavedVariables\<Addon>.lua`.
- **Built-in backup:** players report that the client keeps the previous copy as `<Addon>.lua.bak`. To restore, rename it with the game closed. Forum advice conflicts on how useful this is.
- **Other causes of lost settings:** a read-only or cloud-synced `WTF` folder, or antivirus blocking it.
- **Size:** not a concern. Questie's tests restored about 8 MB, and a layout is a few KB.

## What this means for the addon

- Use one per-character variable, set up in `ADDON_LOADED`, with no library. AceDB's profiles aren't needed for this.
- Keep the addon's folder name and variable name fixed from the first release.
- Keep a `version` number and numbered upgrade steps. A step works on a copy and replaces the original only if it succeeds.
- If the saved version is newer than the addon, leave the data alone and fall back to Blizzard's tracker.
- Test with a full exit and restart, not `/reload`.

## Sources

- [UI/Addon settings wiped on client restart](https://us.forums.blizzard.com/en/wow/t/uiaddon-settings-wiped-on-client-restart/2353992), Blizzard forums
- [Workaround for addon settings resetting on Forever Beta](https://eu.forums.blizzard.com/en/wow/t/workaround-for-addon-settings-savedvariables-resetting-on-forever-beta/630138), Blizzard forums
- [WTFix](https://github.com/eggntoast/WTFix-Public) and [ForeverSVFix](https://github.com/nobewayo/ForeverSVFix), both retired
- [Saving variables between game sessions](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions), [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process), [TOC format](https://warcraft.wiki.gg/wiki/TOC_format), [Create a WoW AddOn in 15 Minutes](https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes), Warcraft Wiki
- [AceDB-3.0 tutorial](https://www.wowace.com/projects/ace3/pages/ace-db-3-0-tutorial), WowAce
- [Problem Saving Arrays](https://wowinterface.com/forums/showthread.php?p=54021), WoWInterface, 2007
- [LibSavedVars: Versioning](https://github.com/Shadowfen/LibSavedVars/wiki/Versioning), an Elder Scrolls Online library
- [WoW Forever settings or keybinds not saving](https://wowforeveraddons.com/articles/wow-forever-addon-settings-not-saving), fan site
- [Lost all data, issue 357](https://wowace.com/projects/rarity/issues/357), Rarity on WowAce, for the `.bak` behaviour
- Local: `reference/Questie/docs/saved-variables-investigation.md`; AutoBiographer's `Migrations.lua` and Baganator's `Core/Initialize.lua` in the game's `Interface\AddOns`
