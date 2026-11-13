# Tracker test bench

Defines and polishes the tracker's look and behaviour without the game. Blizzard's tracker and our proposal run side by side on one fake game, over real screenshots from Ikar's client.

**To open it, double-click `index.html`.** It needs no install or server. Chrome or Edge, because it uses recent CSS.

## What it's for

| Use it for | Don't trust it for |
| --- | --- |
| Layout, hierarchy, spacing, colours, what shows when | Whether the addon's code will work: it runs no Lua |
| Comparing an idea against Blizzard's tracker | The game's rules. Combat limits are modelled from the plan and Blizzard's API docs, not enforced by the client |
| Reading text over real worlds at the game's true size | Exact font rendering. The font is the game's, but the browser draws it, a little bolder |
| Animations, triggers and the order things happen in | Taint, secure buttons and other addons |

Anything that passes here still needs the in-game tests listed in [organiser-design.md](../docs/organiser-design.md).

## Controls

- **View:** either tracker or both, which art set, the world, and the zoom. **Game size** draws one UI unit on 1.8 screen pixels, as Ikar's game does, unless the window is too short to show the tracker.
- **Your own screenshot:** drop an image anywhere on the page. It replaces the world and is remembered until you remove it. It's shown as it is, so the tracker in it stays visible under ours. Take it with the tracker collapsed.
- **Game state:** combat, party size and zone.
- **Layouts:** first login, typical, all open, dungeons, no groups, a fresh install, where everything the game already tracks goes into a new group named Quêtes and auto-tracking turns off, and over 25 tracked, where the last two quests in the groups are past the game's limit and carry its mark.
- **Key bindings:** the addon's four bindings, unbound by default in the game: lock or unlock, collapse or expand all, previous group and next group.
- **Edit Mode and game options:** text size, Edit Mode's 12 to 20, on both trackers. The addon's own text size became a zoom of the whole tracker on 2026-11-10, Ikar's ruling; the bench doesn't draw it, as it's the same picture scaled, and the View's zoom gives an idea. The saturation of the proposal's title and bars. Tracker background, width and height. Height goes below Edit Mode's 400 because the addon's own option will. The opacity of the background behind each quest at rest, in combat, and on hover or when clicked. A quest counts as clicked while its details are open or while it's focused, and 0 means no backgrounds. The proposal's whole opacity in and out of combat, including its item buttons. Map buttons, difficulty colours, the share button only on hover, the group search button, the area highlight, the glow when an objective updates, and auto-tracking, which the addon turns off at install. With it on, accepting a quest or progressing one under Journal tracks it, so it joins the top group. The gear on the proposal's title row opens a menu with three of these switches and Options, which here scrolls to this section and lights it. The title's buttons sit at half opacity until the pointer is over the tracker.
- **Game options, advanced:** sliders for the proposal's spacing and marker size, including "Under the title", how far Suivi tucks under the title row. Copy the values you settle on into the plan.
- **Triggers:** pick a quest, then change its progress or state, make its item usable, change range, start a cooldown, or add a popup or timer. Both trackers react to the same event. **Track** and **Untrack** change the game's list as another addon or the quest log's checkbox would, so the quest moves in or out of a group. Blizzard's side shows only tracked quests, which are the ones in the proposal's groups.
- **Log:** the panel's bottom lists the game events, sounds and calls each action would produce.
- **Other addons:** Spoken's ▶ button and Forever Quest Tint's ∞ marker, both on by default as on Ikar's client. Three fake quests are flagged as new to Forever, so they get the marker and no button. These stand for having each addon installed. They aren't options in our addon.
- **Proposal options:** marker style, and an outline around secure buttons.

Right-click a quest, group or bar for its menu. Drag quests, groups and bars. Your layout and settings are remembered between reloads.

## How it stays honest

- **Numbers come from Blizzard's source.** Sizes, offsets, colours and timings are copied from `reference/wow-ui-source` and named in comments in `css/tracker.css` and `js/game.js`.
- **Art and font are the game's own,** from build 1.60.1.70790. Ikar's screenshots confirm the bronze `c60` art set.
- **Worlds are real screenshots,** copied from the game's `Screenshots` folder. The game's own tracker and frozen tooltips are painted over as they load, using `erase` in `js/worlds.js`. Add `&erase=0` to the URL to keep them.
- **The tracker is measured against the game.** Its position, line pitch and letter spacing come from the same screenshots, and with the same seven quests the Blizzard side lines up with the real tracker to within about 1 screen pixel vertically and 4 horizontally, at 3840 by 2160.
- **Text is real.** Titles, levels and objective names come from QuestieDB's French tables, and format strings from Blizzard's French strings. Progress, items, timers and party data are invented so that every case appears.
- **Item buttons follow the plan's combat rule.** They sit on the stage, not inside rows, and don't move in combat. Turn on "Outline secure buttons" to see them.

**Approximated, not copied:** the opacity background, tooltip, menu and timer panel's borders, the search box, the triangle on Spoken's button, and the map's quest details panel, which is a labelled stand-in. Only the quest section of Blizzard's tracker is rebuilt.

**Left out:** the `[NEW]` tag in the screenshots, which came from an addon Ikar has since replaced with Forever Quest Tint. The map buttons are off by default because the real tracker doesn't show them. Turn them on under Edit Mode and game options.

## Files

| Path | What it is |
| --- | --- |
| `js/fake-log.js` | The character, quests, spare quests and starting groups. Edit this to try other cases |
| `js/game.js` | The simulated game: state, events, objective animation states, triggers |
| `js/ui.js` | Shared pieces: DOM patching, atlases, map and item buttons, tooltips, menus |
| `js/blizzard.js` | Blizzard's tracker |
| `js/proposal.js` | Our proposal |
| `js/worlds.js` | The screenshots, and what to paint over in each |
| `js/bench.js` | The control panel. A new trigger is one line in `CONTROL_GROUPS` |
| `js/selftest.js` | Behaviour checks |
| `js/atlas-data.js`, `art/` | Generated by `quest/tools/bench_art.py`; `art/` is Blizzard's, local only |
| `icons.html`, `js/icons.js` | The addon icon's candidates, drawn in code, shown among Ikar's other addons. `quest/tools/make_icon.py <id>` exports one |
| `area-mark.html` | The area highlight's mark (2026-11-12, Ikar: the arrow misleads): about 130 of the game's small icons, by family, each on a quest row and a group's count at the tracker's size. Click one to mark a pick |
| `js/icon-installed.js` | Written by `make_icon.py`: which candidate the addon holds |

## Checks

Open `index.html#selftest` to click through the behaviours automatically. The result covers the page, and reloading without `#selftest` returns to the bench. It doesn't touch your saved layout. It checks the bench against the plan, not against the game.

A URL can also set up a state, for screenshots or sharing: `index.html#preset=open&combat=1&party=3&quest=60&do=enterArea&background=cave`. `applyHash` in `js/bench.js` lists the options.

## Licences

`art/` holds Blizzard's textures and font and Forever Quest Tint's marker, for local development only, and `art/world/` holds Ikar's screenshots, which show character names and other players' names. Don't publish them or ship them with the addon. QuestieDB's text is GPL-3.0, so `js/fake-log.js` shouldn't ship either. None of this is part of the addon.
