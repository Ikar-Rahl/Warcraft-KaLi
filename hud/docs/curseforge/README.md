# KaLi HUD on CurseForge

How KaLi HUD's CurseForge page is filled, field by field, first on 2026-11-23, as KaLi Quest's
([quest/docs/curseforge](../../../quest/docs/curseforge/README.md)). The texts are in English, as CurseForge asks of
every title and description. Change them in the addon's files first, then on the site.

| File | What it is |
| --- | --- |
| [KaLiHUD/README.md](../../addon/KaLiHUD/README.md) | The project's description: the addon's own README, the one in the zip, pasted as it is in the editor's Markdown mode (its default is the visual one). One text for the page, GitHub and the zip |
| [KaLiHUD/CHANGELOG.md](../../addon/KaLiHUD/CHANGELOG.md) | Each file's changelog: the addon's own, the one in the zip; its version's section (from the line under the version's heading) pasted in Markdown |

Since 2026-11-24 a version goes up from its tag, built and uploaded on GitHub (« Publishing », in the
repository's [README](../../../README.md)). The pictures, the Gallery's and the logo, are in
[docs/images](../images/), to download for the site.

## The project

On [authors.curseforge.com](https://authors.curseforge.com/#/projects/create/choose-game), choose World of Warcraft.

| Field | Value |
| --- | --- |
| Name | KaLi HUD |
| Summary | Adaptable base plate, with minimap, collapsible panels and info bar. (Ikar's, 2026-11-23; also the TOC's Notes, in each language) |
| Description | [KaLiHUD/README.md](../../addon/KaLiHUD/README.md) |
| License | MIT License |
| Links | Issues: `https://github.com/Ikar-Rahl/Warcraft-KaLi/issues`; Source: `https://github.com/Ikar-Rahl/Warcraft-KaLi`. The description's « Bugs and ideas » gives KaLi's mail for players without a GitHub account ([tools/mail](../../../tools/mail/README.md)) |
| Class | Addons |
| Main category | HUDs |
| Additional categories | Map & Minimap, Data Broker |
| Logo | `KaLiHUD-logo-400.png`: the addon's icon (« Dans le V », `kh-dome-v`) redrawn at 400 × 400 by its bench's code |

## The first file: 0.9.0, a beta

As KaLi Quest's and KaLi Recipe's (Ikar, 2026-11-23: "Kali hud work finished").

| Field | Value |
| --- | --- |
| File | `KaLiHUD-0.9.0.zip`: the `KaLiHUD` folder alone (no `_Tests`, no `_Probe`), its TOC at `## Version: 0.9.0`, a folder entry for every folder |
| Display name | KaLi HUD 0.9.0 |
| Release type | Beta: the CurseForge app doesn't sync it unless a player asks for betas, and the app lists a project only once it has a Release file |
| Game version | Forever, 1.60.1 |
| Relations | None |
| Changelog | The « 0.9.0 » section of [KaLiHUD/CHANGELOG.md](../../addon/KaLiHUD/CHANGELOG.md) |

Checked before it was built: the offline tests ALL PASS. In game on build 71037, `/kh test` 67/67 at 13:39 and the
API check 0 failing, with no KaLi HUD line in the game's taint log; the code changed after that (the locked folders,
the evening of 2026-11-23), so `/kh test` is to run again before the upload.

The changelog's 0.9.0 section is the former « 0.1.0 (not released yet) » one with every point kept, its names the
English client's (« Retirer » is **Remove**, « Suite » **More**, « Nouvelle mesure » **New measure**, « Préréglages »
**Presets**).

From 0.9.1 (2026-11-24) the files go up as **Release**, from their tag (Ikar: "Still beta, but the file release shoudl not be beta anymore. So that it is more visible to everyone"): the app shows the project and offers its files to every player. The addon still calls itself a beta, in its README.

## Gallery and video

Taken on 2026-11-23, prepared outside the repository in `release/KaLiHUD-0.9.0/gallery/` (PNG), and in
[docs/images](../images/) as JPEGs at most 1920 wide (`python -I tools/gallery.py hud`), under the same names, in the
Gallery's order. In the style strips (01, 13 to 21) the Trade chat's text is blurred: other players' names. 02 is put
together from the nine strips, each whole under its name, the chat's and the meter's cartouches with it (Ikar
2026-11-24: "The combined image of the style leave out the cartouche, which are a big part of the style"; the first
one kept each style's middle).

| # | In the Gallery | In the description |
| --- | --- | --- |
| 0 | `00-hero.jpg`: the hero, first in the carousel: the logo, the name and the summary, the attribute cards and a folder, three styles' rings unnamed (Forest, Astronomy, Steampunk) and the plate along the foot (Ikar 2026-11-24: "I also lack a hero page", "I like plate", "3, no names") | |
| 1 | `KaLiHUD-video-1-the-plate.mp4`, 2 min 15 s, on YouTube: [BpzNhzMewgY](https://www.youtube.com/watch?v=BpzNhzMewgY) | |
| 2 | `KaLiHUD-video-2-info-bar-folders-stats.mp4`, 3 min 42 s, on YouTube: [nGf-PaR8KSg](https://www.youtube.com/watch?v=nGf-PaR8KSg) | |
| 3 | `01-the-plate.jpg`: the whole foot of the screen, in the default style | Under the opening lines |
| 4 | `02a-four-styles.jpg`, `02b-five-styles.jpg`: the nine styles in two, each under its name (Ikar 2026-11-24: "The 9 style read poorly on an image. Fine in the description, but not as a standalone page") | `02-nine-styles.jpg`, all nine, after « The plate » |
| 5 | `03-chat-and-meter-folded.jpg`: the chat and the damage meter folded into their cartouches, the info bar whole | After « The info bar » |
| 6 | `04-attribute-cards.jpg`: cards kept open over the attributes' folder | After « The character sheet, on a hover » |
| 7 | `05-a-folder.jpg`: a folder of your own, with a named separator | |
| 8 | `06-a-macro.jpg`: the macro editor and the macro's tooltip | After « Folders, macros and notes » |
| 9 | `07-a-note.jpg`: the note's editor and the note's tooltip | After « Folders, macros and notes », under the macro |
| 10 | `08-experience-bar.jpg`: the experience bar's tooltip | |
| 11 | `09-edit-mode.jpg`: Edit Mode and KaLi HUD's dialog beside it | |
| 12 | `10-minimap-rings.jpg`, `11-window-cartouches.jpg`: the rings' and the cartouches' lists | |
| 13 | `12-damage-meter-and-bags.jpg` | |
| 14 | `13-style-…` to `21-style-…`: each style whole | |

« Presets and sharing » has no picture yet.

## How the description was written

As KaLi Quest's and KaLi Recipe's: what it does in the first line, how to start in the first screen, the features
grouped under headings with the feature first in bold, what it leaves alone, a commands table, questions in the
players' words, where bugs go. Every claim is the addon's own: its strings (`Locale/enUS.lua`), its changelog and its
design record ([design.md](../design.md)).

## Published

On CurseForge since 2026-11-23, by Ikar_Rahl: [kali-hud](https://www.curseforge.com/wow/addons/kali-hud), project
1827035. Its id is in the TOC as `## X-Curse-Project-ID: 1827035` since 2026-11-24, so a tag's run uploads
its files there.

Read on the page on 2026-11-24: the file `KaLiHUD-0.9.0.zip` as a beta for Forever 1.60.1, its description rendered, its
logo, and its Gallery empty. No picture was read in the description: perhaps it was pasted before the pictures were in
the repository, or the tool that read the page left them out; still to see in a browser.
