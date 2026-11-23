# KaLi Recipe on CurseForge

How KaLi Recipe's CurseForge page is filled, field by field, first on 2026-11-23, as KaLi Quest's
([quest/docs/curseforge](../../../quest/docs/curseforge/README.md)). The texts are in English, as CurseForge asks of
every title and description. Change them in the addon's files first, then on the site.

| File | What it is |
| --- | --- |
| [KaLiRecipe/README.md](../../addon/KaLiRecipe/README.md) | The project's description: the addon's own README, the one in the zip, pasted as it is in the editor's Markdown mode (its default is the visual one). One text for the page, GitHub and the zip |
| [KaLiRecipe/CHANGELOG.md](../../addon/KaLiRecipe/CHANGELOG.md) | Each file's changelog: the addon's own, the one in the zip; its version's section (from the line under the version's heading) pasted in Markdown |

The files to upload are built outside the repository, in `release/KaLiRecipe-0.9.0/` beside it: the zip and the logo.

## The project

On [authors.curseforge.com](https://authors.curseforge.com/#/projects/create/choose-game), choose World of Warcraft.

| Field | Value |
| --- | --- |
| Name | KaLi Recipe (no other CurseForge project has it, 2026-11-23) |
| Summary | A notebook of the recipes you come across, without spoiling the ones you haven't met. |
| Description | [KaLiRecipe/README.md](../../addon/KaLiRecipe/README.md) |
| License | MIT License |
| Class | Addons |
| Main category | Professions |
| Additional categories | Tooltip, Map & Minimap |
| Logo | `KaLiRecipe-logo-400.png`: the addon's icon (« Plume fendue », `kr-plume-fendue`) redrawn at 400 × 400 by its bench's code |

## The first file: 0.9.0, a beta

As KaLi Quest's (Ikar, 2026-11-23: "ok, second, kali receipe, same").

| Field | Value |
| --- | --- |
| File | `KaLiRecipe-0.9.0.zip`: the `KaLiRecipe` folder alone (no `_Tests`, no `_Probe`), its TOC at `## Version: 0.9.0` |
| Display name | KaLi Recipe 0.9.0 |
| Release type | Beta: the CurseForge app doesn't sync it unless a player asks for betas, and the app lists a project only once it has a Release file |
| Game version | Forever, 1.60.1 |
| Relations | None |
| Changelog | The « 0.9.0 » section of [KaLiRecipe/CHANGELOG.md](../../addon/KaLiRecipe/CHANGELOG.md) |

Checked before it was built: the offline tests ALL PASS; in game on build 71037, `/kr test` 72/72 at 13:39 with no
error saved, the API check 0 failing at 20:40, no file changed since, and no KaLi Recipe line in the game's taint log.
Then, that evening, a name met in another language stands in for « someone » (Ikar, in an English client: "why do I
see Taught by someone everywhere?"): offline ALL PASS, 73/73; in game, to check before the upload.

## Gallery and video

As KaLi Quest's: the Gallery holds the screenshots and the YouTube video in the carousel's order, one picture goes under
the opening lines, then one after the section it shows. In an English client: the names of vendors, trainers and the
creatures that dropped a recipe are kept in the language they were met in, as the game gives none again from a
number, and since that evening one met in another language shows in it rather than as "someone".

Taken on 2026-11-23. The files, outside the repository, are in `release/KaLiRecipe-0.9.0/gallery/`, in the Gallery's
order. Three are put together from the screenshots: 02 keeps the auction house's list and the chat line it wrote, not
the other players' chat; 04 sets the two styles side by side; 09 sets three vendors' tooltips side by side. In 08,
another player's nameplate is blurred.

| # | In the Gallery | In the description |
| --- | --- | --- |
| 1 | `KaLiRecipe-video.mp4`, 37 s, on YouTube: [SmFL6TxUkIc](https://www.youtube.com/watch?v=SmFL6TxUkIc) | |
| 2 | `01-notebook-beside-the-professions-window.png`: the notebook docked, the « Notebook: » line under the rank bar | Under the opening lines |
| 3 | `02-noted-at-the-auction-house.png`: **Note the recipes**, and its chat line: 466 recipes noted | After « Noted where you meet them » |
| 4 | `03-the-notebook.png`: a profession's recipes by category, a recipe's detail below, in Clean | After « The notebook » |
| 5 | `04-two-styles-clean-and-book.png` | |
| 6 | `05-search-and-filters.png` | |
| 7 | `06-counts-in-the-professions-book.png`: each profession's « Notebook: » line | |
| 8 | `07-a-recipe-tooltip.png`: unknown to your characters, one in the bank, who sells it and for what | After « Marks and tooltips » |
| 9 | `08-at-the-auction-house.png`: a recipe's tooltip in the auction house's list | |
| 10 | `09-hovering-a-vendor.png`: never visited, visited without a recipe, visited with two | |

« On the map » has no picture yet: the world map with recipe pins is still to take.

## How the description was written

As KaLi Quest's, after the pages of Kaliel's Tracker, Questie, Details!, Plater, Bartender4 and Leatrix Plus: what it
does in the first line, how to start in the first screen, the features grouped under headings with the feature first
in bold, a commands table, questions in the players' words, where bugs go. Every claim is the addon's own: its strings
(`Locale/enUS.lua`), the former README and changelog, and the design record. The English client's names, read from its
strings and the game's (« Learned » is the game's `TRADE_SKILLS_LEARNED_TAB`, « Already known » its `ITEM_SPELL_KNOWN`).

## After the moderators' approval

The project's id, in its « About Project » box, goes into the TOC as `## X-Curse-Project-ID`; later files can then go
up through the upload API with a token.
