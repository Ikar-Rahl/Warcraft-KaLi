# KaLi Quest on CurseForge

How KaLi Quest's CurseForge page is filled, field by field, first on 2026-11-23. The texts are in English, as
CurseForge asks of every title and description. Change them here first, then on the site.

| File | What it is |
| --- | --- |
| [KaLiQuest/README.md](../../addon/KaLiQuest/README.md) | The project's description: the addon's own README, the one in the zip, pasted as it is in the editor's Markdown mode (its default is the visual one). One text for the page, GitHub and the zip |
| [KaLiQuest/CHANGELOG.md](../../addon/KaLiQuest/CHANGELOG.md) | Each file's changelog: the addon's own, the one in the zip; its version's section (from the line under the version's heading) pasted in Markdown |

The files to upload are built outside the repository, in `release/KaLiQuest-0.9.0/` beside it: the zip and the logo.

## The project

On [authors.curseforge.com](https://authors.curseforge.com/#/projects/create/choose-game), choose World of Warcraft.
A project can only be created there, by its author: the upload API has no call for it.

| Field | Value |
| --- | --- |
| Name | KaLi Quest |
| Summary | Your own quest groups, in a rewritten objective tracker. |
| Description | [KaLiQuest/README.md](../../addon/KaLiQuest/README.md) |
| License | MIT License |
| Class | Addons |
| Main category | Quests & Leveling |
| Additional categories | None |
| Logo | `KaLiQuest-logo-400.png`: the addon's icon (« Noir et or », `kq-noir-or`) redrawn at 400 × 400 by its bench's code |

## The first file: 0.9.0, a beta

Ikar, 2026-11-23: "more like in beta I think now. All features are in", then "0.1.0 is more of an alpha version", then
"no, 0.9.0, a beta".

| Field | Value |
| --- | --- |
| File | `KaLiQuest-0.9.0.zip`: the `KaLiQuest` folder alone (no `_Tests`, no `_Probe`), its TOC at `## Version: 0.9.0` |
| Display name | KaLi Quest 0.9.0 |
| Release type | Beta: the CurseForge app doesn't sync it unless a player asks for betas, and the app lists a project only once it has a Release file |
| Game version | Forever, 1.60.1 |
| Relations | None |
| Changelog | The « 0.9.0 » section of [KaLiQuest/CHANGELOG.md](../../addon/KaLiQuest/CHANGELOG.md) |

The zip holds a folder entry for every folder, as `zip -r` writes it. The first one, files only, was refused on
2026-11-23 with "Failed to verify archive": read by .NET, it showed no root folder.

Checked before it was built: the offline tests ALL PASS; in game on build 71037, `/kq test` 108/108 at 13:40 with no
error saved, the API check 0 failing at 20:20, and no KaLi Quest line in the game's taint log.

## Gallery and video

The Gallery (the « Images » tab until 2025) holds the screenshots and the YouTube videos, in the order of the carousel
at the top of the page; CurseForge hosts no video file of its own. A picture shows in the description through the
editor's image button. The best pages put one under the opening lines, then one after the section it shows.

Taken in game, in an English client, as the quest names are the game's, on 2026-11-23. The files, outside the
repository, are in `release/KaLiQuest-0.9.0/gallery/`, in the Gallery's order.

| # | In the Gallery | In the description |
| --- | --- | --- |
| 1 | `KaLiQuest-video.mp4`, 45 s, on YouTube: [Q2OJeZRcSps](https://www.youtube.com/watch?v=Q2OJeZRcSps) (YouTube files it as a Short) | |
| 2 | `01-your-groups.png`: four groups of your own under Track, the Journal folded | Under the opening lines |
| 3 | `02-several-quests-at-once.png`: three quests picked with Ctrl+click | After « Your groups » |
| 4 | `03-filters-with-counts.png`: the filter menu, each choice with its count | After « Find what you need » |
| 5 | `04-the-journal.png`: the Journal by zone and kind, dungeons and raids apart | |
| 6 | `05-edit-mode.png`: the tracker's Edit Mode dialog beside it | After « Out of your way » |

If the description plays animated GIFs (CurseForge's guides don't say; to check with the first one), a cut of the
video's drag and drop can go after « Your groups ».

## How the description was written

After the pages of Kaliel's Tracker, Questie, Details!, Plater, Bartender4 and Leatrix Plus (Ikar: "You can't do
better? See how other popular addon do it"): what it changes against Blizzard's tracker in the first line, how to open
it in the first screen, the features grouped under headings with the feature first in bold, what it leaves alone, a
commands table, questions in the players' words, where bugs go. Every claim is the addon's own: its strings
(`Locale/enUS.lua`, the Tips page), its changelog and its tests. American spelling, as the game's English.

## After the moderators' approval

The project's id, in its « About Project » box, goes into the TOC as `## X-Curse-Project-ID`; later files can then go
up through the upload API with a token.
