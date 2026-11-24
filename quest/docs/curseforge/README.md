# KaLi Quest on CurseForge

How KaLi Quest's CurseForge page is filled, field by field, first on 2026-11-23. The texts are in English, as
CurseForge asks of every title and description. Change them here first, then on the site.

| File | What it is |
| --- | --- |
| [KaLiQuest/README.md](../../addon/KaLiQuest/README.md) | The project's description: the addon's own README, the one in the zip, pasted as it is in the editor's Markdown mode (its default is the visual one). One text for the page, GitHub and the zip |
| [KaLiQuest/CHANGELOG.md](../../addon/KaLiQuest/CHANGELOG.md) | Each file's changelog: the addon's own, the one in the zip; its version's section (from the line under the version's heading) pasted in Markdown |

Since 2026-11-24 a version goes up from its tag, built and uploaded on GitHub (« Publishing », in the
repository's [README](../../../README.md)). The pictures, the Gallery's and the logo, are in
[docs/images](../images/), to download for the site.

## The project

On [authors.curseforge.com](https://authors.curseforge.com/#/projects/create/choose-game), choose World of Warcraft.
A project can only be created there, by its author: the upload API has no call for it.

| Field | Value |
| --- | --- |
| Name | KaLi Quest |
| Summary | Your own quest groups, in a rewritten objective tracker. |
| Description | [KaLiQuest/README.md](../../addon/KaLiQuest/README.md) |
| License | MIT License |
| Links | Issues: `https://github.com/Ikar-Rahl/Warcraft-KaLi/issues`; Source: `https://github.com/Ikar-Rahl/Warcraft-KaLi`. The description's « Bugs and ideas » gives KaLi's mail for players without a GitHub account ([tools/mail](../../../tools/mail/README.md)) |
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

From 0.9.1 (2026-11-24) the files go up as **Release**, from their tag (Ikar: "Still beta, but the file release shoudl not be beta anymore. So that it is more visible to everyone"): the app shows the project and offers its files to every player. The addon still calls itself a beta, in its README.

## Gallery and video

The Gallery (the « Images » tab until 2025) holds the screenshots and the YouTube videos, in the order of the carousel
at the top of the page; CurseForge hosts no video file of its own. The best pages put a picture under the opening
lines, then one after the section it shows.

The description's pictures are in the repository, `<addon>/docs/images/` (JPEG, at most 1920 wide), and each README
links them through github.com (Ikar 2026-11-24: "I would want the images to be in github, so the description get auto
updated"): a picture pushed to `main` under the same name shows on CurseForge without touching the page. The text is
pasted by hand when it changes: CurseForge's upload API sends files and their changelogs, never a project's
description. The Gallery's pictures are uploaded to CurseForge itself, by hand, from the same folder (Ikar
2026-11-24: "I also want all images to be in GitHub. So I can download them and put them in curseforge").

Taken in game, in an English client, as the quest names are the game's, on 2026-11-23, prepared
outside the repository in `release/KaLiQuest-0.9.0/gallery/` (PNG), and in [docs/images](../images/) as JPEGs at
most 1920 wide (`python -I tools/gallery.py quest`), under the same names, in the Gallery's order.

| # | In the Gallery | In the description |
| --- | --- | --- |
| 0 | `00-hero.jpg`: the hero, first in the carousel: the logo, the name and the summary on the left, your groups large on the right (Ikar 2026-11-24: "Go for 2 and 2") | |
| 1 | `KaLiQuest-video.mp4`, 45 s, on YouTube: [Q2OJeZRcSps](https://www.youtube.com/watch?v=Q2OJeZRcSps) (YouTube files it as a Short) | |
| 2 | `01-your-groups.jpg`: four groups of your own under Track, the Journal folded | Under the opening lines |
| 3 | `02-several-quests-at-once.jpg`: three quests picked with Ctrl+click | After « Your groups » |
| 4 | `03-filters-with-counts.jpg`: the filter menu, each choice with its count | After « Find what you need » |
| 5 | `04-the-journal.jpg`: the Journal by zone and kind, dungeons and raids apart | |
| 6 | `05-edit-mode.jpg`: the tracker's Edit Mode dialog beside it | After « Out of your way » |

If the description plays animated GIFs (CurseForge's guides don't say; to check with the first one), a cut of the
video's drag and drop can go after « Your groups ».

## How the description was written

After the pages of Kaliel's Tracker, Questie, Details!, Plater, Bartender4 and Leatrix Plus (Ikar: "You can't do
better? See how other popular addon do it"): what it changes against Blizzard's tracker in the first line, how to open
it in the first screen, the features grouped under headings with the feature first in bold, what it leaves alone, a
commands table, questions in the players' words, where bugs go. Every claim is the addon's own: its strings
(`Locale/enUS.lua`, the Tips page), its changelog and its tests. American spelling, as the game's English.

## Published

On CurseForge since 2026-11-23, by Ikar_Rahl: [kali-quest](https://www.curseforge.com/wow/addons/kali-quest), project
1826687. Its id is in the TOC as `## X-Curse-Project-ID: 1826687` since 2026-11-24, so a tag's run uploads
its files there.

Read on the page on 2026-11-24: the file `KaLiQuest-0.9.0.zip` as a beta for Forever 1.60.1, its description rendered,
its logo, and its Gallery empty. No picture was read in the description: perhaps it was pasted before the pictures
were in the repository, or the tool that read the page left them out; still to see in a browser.