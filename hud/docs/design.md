# KaLi HUD: the plan

A bronze base along the bottom of the screen that holds the action bars, the minimap, the chat and the damage meter,
with KaLi's own info bar (Titan Panel's job) at its foot. FlareUI's look, Blizzard's buttons. The look was settled on
the draft in `../../art-draft/` (to move into `bench/`).

## Ikar's rulings

On 2026-11-13, in this order (a later line replaces an earlier one):

- The look: FlareUI's bronze. A round minimap in a dome at the centre, two rows of bars each side, a side block each
  end (6 bars, as SpartanUI), the chat and the damage meter in windows at the ends that fold, two status bars as
  SpartanUI's (experience and reputation by default, each configurable), Titan's bar along the foot with the zone and
  the time in it, the mail and tracking in the gaps under the minimap. No end caps.
- Every size can change: each bar's icon size, the windows' widths and heights, the space between the side bars and the
  windows.
- FlareUI keeps the unit frames, cast bars "and such". KaLi HUD handles the bars: action bars, stance (warrior, druid),
  totems (shaman), pet.
- Keep Blizzard's buttons (or FlareUI's skin of them): no buttons of our own to maintain.
- The totem bar exists on Forever (Ikar sees it).
- Our own info bar in place of Titan Panel, with plugins: text, icon, left click, menu entries on right click. Other
  addons' LibDataBroker items show too.
- A third addon in this repository, with the same tests and shared code, linked into the game. Name: **KaLi HUD**,
  `/kh` (picked as KaLi Dock, renamed the same day).
- The art and the info bar are built together.
- No snapping. Instead, in Edit Mode, each spot of the art offers to put a bar there.
- (Afternoon, after trying the spots: too much UI, and the warrior's and the shaman's bars offered at once.) No
  spots, no pins: the plate follows the bars, the chat and the damage meter where they are and draws around them;
  being reactive, there's nothing of ours to manage. Two things: a list of what it accepts, and a maximal distance
  under which it comes to cover it, with minimal overreach. The minimap is on the list too: KaLi HUD will be fully in
  charge of it.

## Who does what

| Part | Who |
| --- | --- |
| Buttons, stance, pet, totem, possess, vehicle bars, their paging | Blizzard (FlareUI may skin the buttons) |
| Where each bar sits | Edit Mode and the player; KaLi HUD never moves one |
| Unit frames, cast bars, auras, nameplates, tooltips, threat window | FlareUI, wherever it puts them |
| Chat, damage meter | Blizzard's frames, FlareUI's skin; KaLi HUD folds them |
| The art, the info bar, the two status bars, the minimap's dressing | KaLi HUD |
| The hub's macros: secure buttons of Blizzard's own template, run on the player's click | KaLi HUD |

## The art

**What the plate takes.** A fixed list (`Frames.ACCEPTED`): action bars 1 to 8, stance, pet, totems, micro menu,
bags, the chat (`ChatFrame1`, with FlareUI's skin), the damage meter (with FlareUI's skin) and the minimap. One is
taken when it shows and its foot stands at most the **reach** above the plate under it: the status bars' top along
the info bar (they lie under the bars wherever those are; Ikar 2026-11-13: with the info bar off, the bars on them
were let go), or a frame's already taken, so a stack of bars is taken from the bottom up and a bar left hanging above
a gap isn't. The reach is
40 units (`/kh reach <n>`, 0 to 400). A frame that doesn't show isn't taken: a shaman's stance bar only while Edit
Mode shows it. Nothing is ever moved: Edit Mode and the player place the frames, the plate follows them in Edit Mode
and is static outside it (see When it redraws).

**Minimal overreach.** Each frame taken gets its slot (its padding, 1 by default) and the plate's margin
(7; Ikar's own as defaults, 2026-11-15) round
it, from the foot up: no reaching to the centre or the edges. Any gap narrower than the reach between two of them, or
between one and the screen's edge, closes up to its lower side (a closing by a flat segment the reach wide), so the
plate holds together without spreading. The minimap stands in a dome: a disc on its ring (no margin past it since
2026-11-13, Ikar: "unnecessary") on an arch up to its centre, and the plate fills up its side where a gap to it is
narrow. Never closer than flush: a margin smaller than the border's metal (`Border.Hug`) counts as that, so the edge
never runs over what it holds (Ikar: "flush, no overlap"). The info bar too: where nothing stands, the plate comes down
to its top plus that metal, so the edge lies on the bar and meets the channel's lip, never over it (2026-11-14).

**Most corners** (`maxCorners`, Edit Mode's plate section, Ikar 2026-11-14: 0 is one straight line; the slider's top,
`DB.UNLIMITED_CORNERS`, the default, no limit). The outline's corners are two a step between stretches, the dome's
arch's included. Past the limit, the stretch that fills the least area going up to its lower higher neighbour goes up
and merges with it, again until the limit is met (`Geometry.LimitCorners`, after `Geometry.Smooth`, smoothed again
after). Only ever up; the arch goes up too when it's the cheapest, then plate like the rest, the disc still on it.
The limit is Edit Mode's (Ikar 2026-11-15: "the corner limit is valid only in edit mode"): a window folding outside it
changes the plate only where it changes for that window (below), never merges anew elsewhere.

**The status bars** sit along the info bar under the level bars taken on each side of the dome (an upright bar
doesn't count), from the map's ring out to those bars' far end; 420 wide with no bar on their side, or the width set.
One dragged in Edit Mode is a frame like the others (see The status bars).

**Drawing.** The plate is the outline of all that: over each stretch of the screen, the highest column sets the top
edge; steps between levels get a rounded corner above and a concave curve below, except against the dome's disc. Drawn
as pieces: the fill, the background's colour lit from the top (0.6 at the foot to 1.0 at the top; 0.75 to 1.25 read
too bright), its material over it (see Borders and backgrounds); its edge the border drawn along the whole outline, its
shadow outside. The info bar and the map's foot are carved in as one channel (`footGroove`): a darker floor, under its
lip (where the plate stands higher than the bar) the lip's shadow, a cut line and a lit line above it; up the walls
under the map (as wide as its ring, up to its centre) the same. Other slots show the plate's background: no recess
(Ikar 2026-11-16: "creux: 0%", then the section gone). They were dark recesses lit from the top left (Ikar
2026-11-14), their upper and left walls' shadow 5 deep and their lips' light 40 % baked in (2026-11-15), the lit lip
then dropped ("the yellow border is ugly"), and their darkness last at 0. The minimap pockets' free places are still
marked as small round recesses (`pocketMarks`, now in the Minimap section: "move the minimap hint under minimap
category, so you can remove the creux category altogether"), near black at 40 % (`RECESS` in `Plate.lua`, the slots'
default darkness as it was), as is the recess round a map with no ring. Strata BACKGROUND, no
mouse; it never touches a protected frame, so a fight changes nothing.

**When it redraws: static outside Edit Mode (Ikar 2026-11-15: "people do not expect their UI to change with
dynamic events"; "in edit mode it adapts, but after that, it should be static regardless").** In Edit Mode the plate
reads the frames live, every frame (see Live drag tracking). Leaving it, they're frozen as they then stand
(`Plate.Freeze`, the next frame, once Blizzard has hidden what it shows for Edit Mode alone), with what each status bar
had to show, and saved for the character (`KaLiHUDDB.plates[realm-name]`: the screen's size, the time, each frame's
name and rectangle, each bar's kind and whether it showed). From then on the plate is drawn from that, whatever the
game does: a pet called or dismissed, a vehicle, the stance bar, the bags unfolded, a status bar with nothing to show
(the XP bar at the level cap keeps its place until the next Edit Mode), a frame another addon moves. Frozen again:
leaving Edit Mode, the UI scale or the resolution changing, `/kh redraw`. **Not for bars changed outside Edit Mode
either** (the review's D6; Ikar 2026-11-17: "No, only in edit mode, I don't think the user will be happy with the new
form without changing the other bara", the other bars): an action bar ticked or unticked in the game's options, or
another Edit Mode layout the game applies with the specialisation, leave the plate as frozen until Edit Mode is
opened or `/kh redraw`. A plate that took a new shape by itself would stand wrong beside the bars the player hasn't
arranged for it yet. **What the player moves himself is followed**
(Ikar 2026-11-16: "add support for the user actions"): the chat dragged by its tab or sized by its grip, the damage
meter's window dragged or sized, outside Edit Mode, have that frame's record in the freeze read again once he lets go
(`Plate`'s `follow`, on Blizzard's own `StopMovingOrSizing` that ends such a drag, hooked on each accepted frame and on
`DamageMeterSessionWindow1`; the next frame, once Blizzard has docked or anchored it), and saved; nothing else is read. At login the
character's freeze is used when made at this screen's size; else the frames are frozen 3 seconds after the world shows,
late frames come. What still redraws it outside Edit Mode is the player's: an option, a window folding (its own place
alone), the reach, a frame he moved. Asked many times, it's drawn once a frame. Nothing else watches the frames outside
Edit Mode: no hooks on their showing, no check once a second, no looking each frame while a button is held (all
gone). `/kh status`
lists each frame (taken, hidden, or how far out of reach) and when the plate was frozen.

**The icon** (the TOC's `IconTexture`: the AddOns list and the addon compartment) was `make_media.py`'s bronze dome on
its plate until 2026-11-23. Now it's H1.1, « Dans le V », on the bench's `icons.html`: KaLi Quest's « Noir et or » tile
and its K, at its size and place (38 high in the 64 file, as Ikar asked: "the K need to be of the same size"), with
the minimap's dome in the K's open side, between arm and leg, its arch and plate behind the leg; a dark gap parts the
K from the dome where they cross. Ikar's pick ("H1.1 is good, set it") from two rounds: ten signs of the HUD, then ten
ways to fit H1's dome, which first read as a padlock ("the dome is good, but it look like a lockpad"): a whole disc on
a narrow base does. `python -I hud/tools/make_icon.py kh-dome-v` writes `Media/Icon.tga`; `make_media.py` no longer does.

## The info bar

**A plugin is a LibDataBroker data object**, the format every broker display reads, plus one field of KaLi HUD's own:

```lua
LibStub("LibDataBroker-1.1"):NewDataObject("MyAddon", {
    type = "data source",                 -- or "launcher"
    text = "12,4k", icon = "Interface\\Icons\\INV_Misc_Bag_08",
    OnClick = function(self, button) end, -- left click; the right click too when there's no menu
    OnTooltipShow = function(tooltip) end,
    menu = {                              -- KaLi HUD's: the right click's entries
        { text = "Afficher les centimes", checked = function() return opt.copper end, func = function() end },
    },
})
```

- Every data object shows, ours and other addons' (KaLi Recipe, Spoken, SilverDragon, Libs Error Display...).
- A right click: one of ours opens its hub menu, its `menu` first (Blizzard's Menu API); another addon's object gets its
  own `OnClick` with `RightButton`, as Titan does, while the padlock is shut, and the hub menu once it's open (One
  right-click, below); the bar's own menu shows or hides each one.
- Our items are data objects too, so they'd also work in Titan or any other display. Each is offered once, when this
  character has it and it has a name a player reads there (`Hub`'s `publish`): all were published, 95 in the test
  session, 31 of them another class's reagents or statistics the build doesn't know, with no label (the review of
  2026-11-17, D11). One named later (an item's name the game hadn't loaded, a skill learnt) is offered then. The
  library itself may come with an addon loaded after login: looked for again as each loads.

**Items, from Ikar's Titan bar:** the zone, fixed right under the minimap (Ikar 2026-11-13: never an element: no hub
menu, no hints, never dragged nor hidden; the block below the minimap is laid out so the zone stands under its
centre); coordinates and clock, elements like the rest, either side of it by default; bags (used slots, click opens
them); gold (every character, this session, per hour); repair (cost, most damaged item); experience (per hour, time to
level); performance (frame rate, latency, memory); speed; volume (sliders).

**More items (`UI/Hub/Infos/`; Ikar 2026-11-16, his list from a catalogue of info-bar addons, with his tests: "I don't
want to add things that belong more in a spell slot, like feeding the pet, poisons, or portals... avoid those who need
serious code, tracking, data storage... no one that breaks immersion, or provides gaming shortcuts that make the player
a bot").** Each read from one of the game's calls, or the game's own tool opened; nothing kept but what a session
counts. Each stands in the folder made for it (Folders, below), from which it can be dragged anywhere; each named, as
the bar's menu and Edit Mode list it (the game's word where it has one: « Munitions », « Guilde », « Méthode de
fouille »...), never by its id (the review of 2026-11-16 found eleven that were):
- **Weapon skills** and **professions**: one item per skill line the skills tab lists (`C_SkillInfo`), its rank out
  of its maximum, a bonus in green; weapons with defence (category 6 of this build's `SkillLine`), professions with the
  secondary skills (11 and 9), none of a single rank (racials, dual wield); each profession and secondary skill with an
  icon of its own in the table its icon (poisons, kodo riding included), the weapon skills and the other mounts' none,
  the table giving them all the same. A skill learnt shows, last of its folder;
  one unlearnt goes. Fishing's tooltip gives the zone's levels (Ikar: "fishing, the zone level"), and where a cast
  lands (« Pêche ici », below). A click opens the professions book, or the character's skills. **Forever's map data
  gives no zone a level range** (2026-11-18, Ikar: "I don't see fishing zone level, why ?"): every zone's UiMap and
  AreaTable row has no ContentTuning, so `C_Map.GetMapLevels` has none to give and that line never showed, nor the
  bar's « Niv. » (seen in game: "why Niv is empty ?"; Classic Era's UiMap has its LevelRangeMin and Max all 0 too).
  **The zones' levels are now Forever's own Group Finder's** (Ikar 2026-11-18: "Add the table, scrap the data", "for
  forever, be carrefull"): its « Quests & Zones » category lists one activity a zone, from its lowest level to the
  highest it suggests (DB2 GroupFinderActivity's MinLevel and MaxLevelSuggestion), Forever's ranges and not Classic's
  (Elwynn Forest 1-14, Westfall 8-24, where Classic says 1-10 and 10-20; the guide sites disagree with it and each
  other, so none is used), with its new zones' (Riverglades 33-54, Zephras Isle 1-14, Mount Hyjal 55-60).
  `hud/tools/make_zones.py` fetches the table from wago.tools for this build (`--fetch`, under a browser's name, the
  site refusing Python's: Ikar "I allow, go scrapp"), matches each activity to the zone maps of its name (UiMap type
  3; « Hinterlands » is « The Hinterlands ») and writes `Data/Zones.lua`, 42 maps, which the tests check against it.
  The map the player is on, or a cave's or a building's zone (a micro map's parent); a zone the Group Finder doesn't
  list (the cities, Moonglade, Deadwind Pass, Shen'dralas) and an instance have none, « — ».
  **Where a cast lands, « Pêche ici »** (Ikar 2026-11-18: "how to get the fishing areas zones ?", then "Go for it, but
  don't show a line, add a question mark icon"): the game's client has none (the server rolls each cast against an
  area's base skill; no table of Forever's carries one, wago.tools' list included), so the bases are **the original
  game's**, its own data (Ikar 2026-11-22: "theses are in game data"), kept by area in `make_fishing.py`, as
  OpenMap, BetterMaps and Pagle take them too. Ikar chose them knowing they are Classic's: the four that Pagle's
  catalogue marks confirmed on Forever (Wetlands, Redridge Mountains, Tirisfal Glades, Darkshore) are the same.
  The server's rule: a cast lands from the base, (skill − base + 5) % of the
  time, every one from base + 95; the line gives that range (Westfall 1-75, Stonetalon 55-150, Silithus 330-425), green once every
  cast lands, red while none can, against the rank with its bonus. A dungeon's by its instance (`GetInstanceInfo`'s
  instance ID: Forever has no dungeon maps), else a sub-zone's own (Jaguero Isle, Jademir Lake, Azshara's Bay of
  Storms, Hetaera's Clutch, Scalebeard's Cave) by the name the game gives its area in the player's language
  (`C_Map.GetAreaInfo` against `GetSubZoneText`, in its zone only), else the zone's, a cave's being its zone's.
  `hud/tools/make_fishing.py` finds each area in Forever's tables by its ID, never a name (a zone by the maps
  `UiMapAssignment` gives it), and writes `Data/Fishing.lua`: 43 zone maps, 5 sub-zones, 9 dungeons, checked by the
  tests. Where none is known, Forever's own zones (Mount Hyjal, Zephras Isle, Riverglades, Shen'dralas) and the three
  the original game had no water for (Badlands, Blasted Lands, Searing Gorge), **a question mark** (the game's
  `QUESTION_MARK_ICON`), never a dash.
  **A bonus says where it comes from** (Ikar 2026-11-18: "for fishing, I see only bonus +5, not the source"), as an
  attribute's, by the same tally (`Stats.ShowSkillSources`): the spells whose auras change that skill line
  (`Data/Effects.lua` now keeps auras 30 and 98 on every line, defence's attribute keeping its own), so a lure on the
  rod for a while (« Fishing Lure +25 », its spell 8082), the gloves' « Pêche +2 » (13615), a buff, a set, a talent,
  the race's passive spell; and an item's own bonus, which Forever makes an item stat (a rod's, 117) that
  `C_Item.GetItemStats` keys by no name of the game's strings: read from the item's line as the game words it,
  `TOOLTIP_ITEM_STAT_SKILL_<skill>_INCREASE` and `_DECREASE` (« Équiper : pêche augmentée de 5. »), each skill line's
  word by its id (`Stats.SKILL_WORDS`, checked against this build's French names; inferred, unverified in game). What
  nothing names is « Autres ». None during a fight.
- **Attributes** (Ikar: "stats, main and secondary, all of them"; "regen"; then "review all the stats, are they
  displaying the correct information for Forever? This is important"): every one Forever's character sheet shows
  (`Camelot/PaperDollFrameConstants.lua`'s kinds, then `CharacterFrame.lua`'s resistances), in its order, its kinds
  apart, by its names and its calls; mana in five seconds (or energy, rage a second) with them, the sheet's names for
  energy and focus; zeros kept (Ikar: "keep the 0, they are in a folder anyway"; the sheet hides them). Its values as
  it computes them (`PaperDollFrame.lua`, `PaperDollFrameStats.lua`), checked one by one against it and this build's
  docs (their returns' order):
  - general: health, power (the form's), movement speed (how fast one can go: running, or swimming or flying while
    one does, 100 % standing still; not the bar's « Vitesse », how fast one goes now, which the folder took first),
    read each second as the sheet's while it shows;
  - the five attributes, lowered red but under the PvP gear rules (`GetPVPGearStatRules`), raised green;
  - weapons: each hand's damage « 41 - 64 », « 120-180 » from 100, green or red by its bonuses as the sheet's (ranged
    by its multiplier only, as its own); attack powers never below 0, or the spell power they're taken from
    (`GetOverrideAPBySpellPower`);
  - modifiers: hit the best of melee, off hand, ranged and spells, a critical strike the best of melee, ranged and
    spells (gear gives one hit and one critical strike on Forever, its items' stats 31 and 32 alone, but talents and
    caps keep them apart: 8 % in melee, 17 % with spells against a raid's boss), haste ranged with its ammunition's,
    expertise the off hand's after a « / », spells' power the lowest school's; chances to one decimal in the player's
    way of writing them (« 4,5 % »);
  - defence out of the level's most (« 300 / 300 »), dodge and parry to one decimal, block whole, armour green when
    raised, never red;
  - resistances: arcane, fire, frost, nature, shadow, each with the sheet's icon, green when raised.
  All read again on the sheet's events that can change one (Ikar: "Do all stats react to buffs and debuffs?"): the
  auras' (`UNIT_AURA`: a buff can change a chance, a haste or a regeneration with no other event), talents', gear's,
  the quiver's (`BAG_UPDATE`), the level's, spell haste's and damage's modifiers'. The unit events for the player
  alone (`Infos.OnPlayer`, `RegisterUnitEvent`; the review of 2026-11-23: the game had sent every unit's, a raid's and
  the nameplates', to be dropped), counted and traced as the others. On hover (Ikar: "Do they show the
  source of each change and the baseline?"), after the value, its changes as the sheet's tooltip gives them: « 120
  (105+20 -5) », the raise green, the fall red, for the five attributes (the base the current value less both), the
  attack powers, defence, armour and resistances (their bonus either way), a weapon's damage (its base damage, its
  bonuses and multiplier); nothing when unchanged. The game has no figures for the others (health, power, chances,
  haste, spell power). **Where the changes come from** (Ikar 2026-11-16: "there is no list of modificators on each,
  from where the +10 or -2 come from"; 2026-11-17: "I don't see the effect of my elixirs and buffs"), under it, for
  every one but the weapons' damage: each item that carries some, in its quality's colour, by how much (its stats by
  the game's names, `C_Item.GetItemStats`: an attribute's, the attack power's, the ranged one's with the melee one's,
  defence's, the bonus armour, a resistance's, the health's, the mana's, the spells' power, damage and healing, the
  spell penetration, the mana in 5 s; a rating, hit, critical strike, dodge, parry or block, as the share of a percent
  the sheet makes of it, `GetCombatRatingBonus` over `GetCombatRating`, its own percent when the character has none);
  each buff then debuff whose spell changes it, by its points (of a percent for a chance, a haste or the speed) or its
  share of the whole (« +10 % (+11) », what it comes to when it's the one share there) or of the base, a spell damage
  on some schools only with their names (« Puissance de feu (Feu) »), from what each spell's auras change in the
  game's data (DB2 SpellEffect: their kinds, listed in `hud/tools/make_effects.py`; `Data/Effects.lua`, written by it
  and checked against this build's data by the tests) and the aura's own values (`AuraData.points`, numbered by the
  spell's effects or by its auras alone: both kept), else the spell's own in the data where they're the aura's
  whoever casts it (an elixir's, a scroll's; not a buff growing with its caster's level, named without them); then,
  for a value the game gives the changes' sum of (the five attributes, the attack powers, defence, armour and
  resistances), what's left, « Autres » in grey: that sum less what's named, a share's worth set apart. Nothing left
  when a source's values are unknown or beside the armour's and resistances' share (their base not split from the
  gear's), nor a point either way beside a share (the game's rounding). The mana's and its regeneration's only for a
  character with mana. None during a fight; a failure once leaves the value's hover as before for the session.
  **Every source (Ikar 2026-11-17: "Can we extend to include all sources?", then "Do your best guess").** The game has
  no call that says what a spell, an enchantment or a set changes, only the numbers of an aura (`AuraData.points`) and
  translated text; so what each changes is the game's data, `Data/Effects.lua`, and what the character has is the
  game's calls. Under the value, first what it stands on, unsigned, as a sum's terms, the sheet's own sums
  (`PaperDollFrame_SetStatTooltip2`, Camelot's): what each attribute gives at its value now (the attack powers'
  strength and agility, `GetAttackPowerForStat`, `GetRangedAttackPowerForStat`; health's stamina, the first 20 a point
  each and `UnitHPPerStamina` after; mana's intellect, `MANA_PER_INTELLECT`; the critical strike's agility and
  intellect, `GetCritChanceFromStat`, `GetSpellCritChanceFromStat`; the dodge's agility,
  `GetDodgeChanceFromAttribute`; the mana regeneration's spirit, `GetManaRegenFromSpirit`; the armour's agility, 2 a
  point, a local of Camelot's sheet) and each item's own armour (inferred: `C_Item.GetItemStats`' `RESISTANCE0_NAME`,
  the key under which the game names an item's armour among its stats); then, for a value the game gives the base of,
  the rest, named after where it comes from (below), so the terms add up to the base. A value
  nothing changes shows that alone, its base where nothing is named of it (Ikar 2026-11-19: "defense has no
  source": a defence of 300 with no bonus had an empty column). A value the game gives no base of (`total`: health,
  mana, the speed, the hit, the critical strike, the haste, the spell powers and penetration, the dodge, the parry,
  the block, the expertise and the armour penetration; the armour and the resistances too since Ikar's screenshot
  of the same day, the game's split of them being no base and changes: Forever's `UnitArmor` « bonus » is the items'
  and the agility's armour, its base the buffs' (the probe: 10 and 798; his: 202 and 821), which named his items
  twice, « Base -619 » beside « Autres +619 ») has what its named sources leave of it, so its rows come to
  it (the review of 2026-11-19: a health of its stamina and gear alone came short of it): its base first, named
  after where it comes from (below), for one that has one; « Autres » among its changes for one that has none (the
  hit, the haste, the spell powers, the expertise, the armour penetration, and since 2026-11-21 the armour, the
  resistances and the mana regeneration: their sources are all named, nothing of the race's, the class's or the
  level's left in them). None while a
  source's points are unknown or a share can't be worked out, nor beside a source of some schools alone (a spell
  power is its least school's). The dodge's, the parry's and the block's defence is named among what they stand on:
  0.04 % a point past five a level, the sheet's `PaperDollFrame_SetDefense`. One nothing gives, at 0, says so,
  « Aucun » (the game's `NONE`), its column not left out (Ikar: "expertise is 0": five spells of this build give
  expertise, Forever's own, none of them kept by the data, so 0 is the game's figure). An item's row has its icon
  before its name, as a buff's, a talent's, a passive spell's and a consumable tried have theirs (a scroll's
  « Armure » +60 read as unclearly), and a group its name over it even with one row (Ikar, of his mace « Écrasante de défense »'s +3
  defence, alone under no « Équipement »: "Unclear"). A row's name is cut where its figure starts, a figure wider
  than its 70 points having run over it. Under « À savoir », after the sheet's « Augmenté par » words, what a point of
  each attribute that raises the value gives (Ikar: "would be nice to augmenter par to show the ratio"): « Force : 2
  Puissance d'attaque par point », « Agilité : 1 % Critique pour 20 points » (below 1 a point, the points that take
  1), worked out by the game's own call at the value now and a hundred points further (the first 20 of stamina and
  intellect giving 1, said); defence's past the level's most; a resistance's points for 1 % at the character's
  level; and for a weapon its speed and its damage a second, the sheet's damage tooltip's (every value has something
  to know, Ikar: "some characteristic don't have info part"; then "haste has no description, other stats with no
  description ?": the haste what it is in the game's own strings, `STAT_HASTE_TOOLTIP` for a class with mana,
  `STAT_HASTE_MELEE_TOOLTIP` else, not the classes' own, Mainline's, a hunter's focus; the armour penetration its
  text's second sentence, below 0 more damage, routed there by hand, its « 0 » having filed it with what it gives;
  the spell penetration's text at 0 too, its « per point » a point's share in percent, 75 / (5 × level), where the
  sheet's own puts the whole as a fraction, 0.0 % at most values; and the defence where its « / 115 » comes from,
  « 115 : le maximum de la compétence au niveau 23, 5 par niveau. Elle monte quand vous êtes attaqué ; les bonus s'y
  ajoutent. », and what its skill lacks of it, Ikar: "defense I have 113 / 115, where the 115 come from ?"). The
  haste and the speed have no rest said: their changes multiply each other, and what the sources leave isn't a
  figure of anything (a curse's -50 % had left « Autres +55 % »). An effect worth 0 is no source: the data had
  written a 0 as a blank, which the card read as a figure missing, a question mark and no rest (96 spells, 62 of
  them passives, Berserker Stance's attack power among them; the audit of 2026-11-19, Ikar: "other suspicious
  sources of unknown ?"); `make_effects.py` writes « 0 » since. The spell power's « up to » counts holy too, which
  the sheet's own leaves out. What is and what would be are joined by the game's own arrow, `common-icon-forwardarrow` as its
  character creation writes one in a line: the font has no "→", an empty box on his screenshot. Then its changes, as
  before and with these:
  - **an item's enchantment**: its id is the link's (`item:<id>:<enchantment>`), what it gives the data's
    (SpellItemEnchantment: a stat by the game's number, the code's own list of them checked against the
    enchantments' English names; a resistance; the armour as bonus armour; or the spell it puts on its wearer, kept
    in `EFFECTS`); named by its slot alone, « Enchantement (Poignets) » (`L.STAT_ENCHANT` round the game's
    `<slot>SLOT`), in the game's green, since 2026-11-19 (Ikar: "I would prefere Enchantement (bracelet) + 4, no full
    name of the item, just it slot suffice"); before, by its line in the item's tooltip (« Enchanté : Force +4 »), else
    the item's name and the game's « Enchantements »; an amount that follows the item's level, named without it;
  - **a weapon's oil or stone**, for a while: `C_Item.GetWeaponEnchantInfo` by `Enum.WeaponSlot`, the permanent ones
    there left to the links; named by its slot as the permanent ones;
  - **a set's bonus**: each worn item's set (`C_Item.GetItemInfo`'s 16th), counted, each spell the set gives from so
    many pieces (ItemSetSpell) at that count or more, as the game's « (2) Ensemble : <the set's name> »;
  - **a talent at its rank**: Forever's talents are trait nodes (Blizzard_PlayerSpells' Camelot ClassTalents, as its
    frame reads them: `C_ClassTalents.GetActiveConfigID`, or the active group's configuration, its trees, each node's
    `activeRank` and entry, the entry's definition's spell); its value at that rank the trait's own curve
    (TraitDefinitionEffectPoints, CurvePoint; 663 of the 665 definitions have one, all "set"), the spell's own points
    for a talent of one rank without one, unknown else; named « <name> (Rang 2/3) », the game's `TOOLTIP_TALENT_RANK`;
  - **a passive spell of the race or the class** the character knows (`C_SpellBook.IsSpellKnown`; the passive spells
    of SkillLineAbility, SpellMisc's passive attribute, the talents' left out), « Vivacité (Passif) », the game's
    `PASSIVE_PARENS`;
  - each only where what it needs is there (SpellEquippedItems, SpellShapeshift: a talent of melee weapons with one
    in hand, a form's passive spell in the form, `GetShapeshiftFormID`'s number less one in the masks); an aura the
    game applies is counted as the game applies it;
  - **the camp's benefits**, a row each, « Camp : » and the item's name with its icon, « Camp : Bougie d'encens »
    (Ikar 2026-11-22: "we see it in avantages de feux de camps", then, seeing one row named after the buff, "camp:
    name of the item"; « Lager », « Campamento », Mexico's « Hoguera », the buff's own words). Each is a hidden aura
    the game gives no addon: `C_UnitAuras.GetPlayerAuraBySpellID` gave nothing for any of them, though Ikar had the
    fish bowl. But the buff's tooltip (`C_TooltipInfo.GetUnitBuffByAuraInstanceID`) writes a line for each one the
    character has, « Bocal à poisson : augmentation de toutes les caractéristiques de 8 %. ». A line is found by its
    start in the client's language (Data/Effects.lua's `HIDDEN_PARTS`, written by `make_effects.py` from the Spell
    table in the five languages); the item's name is what comes before its colon. Its figures are the ones the line
    writes: the buff's text gives them as `$<spell>w<n>`, the aura's own amount on the character, and Forever gives
    less than the data's at a low level (Ikar's incense candle at level 26: the data's +25 counted, the sheet's bonus
    +15 in all, « Autres -16 »). Each effect's `w` says which of its line's figures is its; one its line doesn't
    write takes the figure of an earlier one of the same aura and points (the lute writes one resistance of six),
    and the data's where none. In a fight, where that text may be secret, and in another language, they stay in
    « Autres ».
  A spell met among the auras isn't named again as a talent's or a passive's (inferred: whether the game lists its
  passive auras with the others is the probe's to say). « Autres » keeps what's left, less of it now: its words'
  « talents, enchantements » went with them (« Others », « Sonstiges », « Otros »). The tables come from wago.tools
  for the build (`make_effects.py --fetch`), into the reference copies.
  **The cards check themselves (Ikar 2026-11-22: "why didn't you catch them on your numerous reviews ? Is there a
  better way to do it ?", then "ok, go, and add that to the error report").** Every stat mistake found in game had
  passed the reviews: each review held the code against a reference (the sheet's code, the data, the original game,
  other addons), and the fake and its tests are written from the same references, so they agree with the code where
  Forever does otherwise; « Autres » took whatever was left, so a wrong rule showed as a believable figure. The game
  is the one check of the figures, so:
  - what's left below 0, the card counting more than the game gives, is « Erreur de l'add-on » in red with its
    question (`STAT_ADDON_ERROR_LESS`), not « Autres »: the addon's mistake most likely (a base's below 0 too, with the
    attack power's); what's left above 0 stays « Autres », a source the game may hide;
  - a card drawn that can't account for all of the game's figure keeps, in KaLiHUDDevDB.statChecks
    (UI/Hub/Infos/StatCheck.lua): its rows, what's left, what its value's own calls gave (`Stats.ReadValue`: numbers,
    total, parts, the kind of attack) and the state its sources were read from (`Stats.ReadState`: level, race,
    class, form, power, attributes, the auras with the camp's text, each item's string, stats, kind and set, the
    oils, the talents with their words' figures, the passive spells known, the ratings, how it moves; no name of the
    character's or the realm's). The same card with the same rows once, counted a look each time (the card kept open
    drawn again is none); 40 of them, the last `/kh stats` whole, then those that can't account for all of it, the
    last seen first; the states shared, nothing kept of what changes from one moment to the next (the speed it goes
    at, an oil's time left, an aura's instance where its text isn't kept). The review of 2026-11-23 had found each
    `/kh stats` keeping a card a value and pushing the older cards with a gap out, each redraw of the card kept open
    counted a look, no two states the same, and the report's text read back changed: a line break's code before a
    figure took the figure in ("\10" and "60" read "j0"), every code now in three figures.
    `/kh stats` keeps every card as it is; the bug report lists them and gives each with a gap as a Lua case; `/kh
    clear` empties them with the errors. Not in a fight;
  - offline, `hud/tools/card_cases.py` prints a kept card from the saved file as a case of
    `hud/tools/lua/scenarios/cards.lua`, which reads the card again from it alone (the fake's `F.Replay`, the value's
    own calls given back) and holds it to what it must leave once fixed: the tests then come from the game. The
    scenario's own cards, kept on /kh stats and read again inside another character's state, prove the state holds
    all a card reads (23 `cards:` breaks). Bringing that out, the smoke's bear form had left « Autres -49 » all along:
    the fake's attack power never had the form's +69.
  **The best of three (Ikar 2026-11-19: "the haste value seems doubled, can you double check every characteristics,
  how it is computed, verify correctness for each").** The values were checked again against the sheet's code and are
  its own; the fault was under them. The hit chance, the critical strike and the haste show the best of the melee
  attacks', the ranged ones' and the spells'; a buff of melee haste and ranged haste has two effects (the troll's
  Berserker three, with the spells'), and the sources added them: 10 % read +20 %. In this build's data 28 spells do
  so for the haste, 52 for the hit, 30 for the critical strike. A source now counts for the kind of attack shown
  alone (the best, the first when equal), each aura's kind naming the attacks it changes (54 and 52 the weapons', 55
  and 57 the spells', 290 both; the haste's 319 melee, 140 ranged, 192 and 342 both, 65 and 216 the spells', 193 all
  three), the rating's share that kind's, and the critical strike stands on its agility's or its intellect's, not
  both; the sources' title says which (« Sources (Mêlée) »). Kinds the data has and the list ignored are read too: the
  spells' haste, the gloves' « Hâte mineure » (342), every critical strike (290), a combat rating an aura gives (189,
  its misc a mask of the ratings, worth what an item's is), the health's 230 and 250, the armour's base by a share
  (142), the mana regeneration's shares (110, 134, named without what they come to), and the haste rating four
  items carry.
  **What a value gives (Ikar 2026-11-19: "can you show, separatly, not only the source for each, but what each
  provide ?").** The sheet has a text for each value, in the player's language and the class's own, with its figures
  (« Augmente la puissance d'attaque de 220 », « Réduit les dégâts physiques subis de 38,52 % »): built here as the
  sheet builds it (`PaperDollFrame_SetStatTooltip2` and the others, their figures worked out the same way), then cut
  in three: its paragraphs with a figure are what the value gives, the others what it is, and from the first grey
  one on its notes. The expertise's is the ranged one's, as the sheet's own (its code asks a `category` nothing
  sets). **The card (Ikar: "make a custom 3 panel, left the input, center the value, description, tips, and right
  effects ? what do yo uthink ?"; "I want to explore the concept first before you do too much lua stuff"; of three
  sketches, side by side tooltips, one tooltip in sections, one card, "One card, but enhance it, explore way to make
  it niced"; of three cards, a plaque, a medallion, a compact one, "Go with card 1").** An attribute's hover is no
  tooltip but a card of the HUD's own (`UI/Hub/Infos/StatCard.lua`), in a folder's list's border and floor, so in the
  style chosen, over the element and kept on the screen. Its head: the name, and on the right the value, large, its
  base and changes before it. Under it up to three columns, one with nothing to say left out: « Sources », what the
  value stands on (several items' own under « Équipement » with their sum; the base alone when nothing is named
  under it), a line, then its changes under « Bonus » with their sum where the game gives it; « À savoir », what the
  sheet's text says the value is, and its notes in grey; « Effets », what it gives, as figures each over the game's
  own name for it where there is one (an attribute's share of the values it feeds, an attack power's damage a
  second, the armour's share of the blows: « +220 Puissance d'attaque »), else the sheet's sentences. Its foot the
  hints a tooltip had. It takes no click, goes with the pointer, and a click anywhere takes it away as it takes a
  tooltip. A skill's sources stay under its tooltip.
  Since 2026-11-20 (Ikar: "the bottom hints could be displayed in one line"; "a border color glow for input and
  output ? like green for inputs, purple for outputs ? A hint, not too strong"): what the clicks do is one line at
  the foot, its hints apart by « · », the questions' answers a line each above it; and a soft light, added and
  fading in over 36 units, runs down the card's border beside « Sources » (green) and beside « Effets » (blue, purple
  first: "switch purple to blue"),
  from the head's line to the foot's, at most 0.22 at the border; none beside a column the card hasn't. The kept
  card's foot as before. Not yet seen in game.
  Every attribute has the card (Ikar 2026-11-19: "What about the other characteristics ? they don't have a crd ?":
  they had, with the sheet's sentences where the first had figures): figures too for the hit chance, the critical
  strike and the haste, each kind of attack's under the game's word for it, the block's value, the defence's share
  either way and a resistance's average. Among what a value stands on its base comes first ("base should be first
  no ?"), then the gear, then what the attributes give.
  **Caps and values worth reaching (Ikar 2026-11-19: "find for every carachteristic any possible cap, golden value
  etc."), then against the value now ("go for the live").** First under « À savoir », each a line and under it
  « atteint », green, or « il manque … »: against a raid boss, never to miss with each kind of attack (8 %, 17 %
  with spells, 27 % with two weapons while two are held), none of its critical strikes (the defence of five a level
  and 140), never dodged by it (6.5 % of expertise; its parry left out, the game's texts giving 14 and 16.5 %: see below);
  the armour's most, 75 %, and the armour short of it, asked of the game's own sum value by value
  (`C_PaperDollInfo.GetArmorEffectiveness`, doubled then halved down to the point; the share short of it when the
  game never gets there); a resistance's most on average, 75 % at five points a level. The figures are the game's
  texts' and its sheet code's, constants here where the game has them as text alone; a caster's card names the
  weapons' hit too, the game not saying which kind a class fights with. What this build's own texts and sheet code
  state, so Forever's: hit, never
  to miss a raid boss 8 % with weapons, 17 % with spells, 27 % with two weapons (a target of one's level 5, 4 and 24:
  `CR_*_HIT_CAP_TOOLTIP`); defence, 0.04 % a point past five a level, a raid boss striking critically no more from 440
  (−5.6 %; by the sheet's sum, five a level plus 140), a creature's critical strike 200 %, a crushing blow 150 % from
  three levels above, which defence past the level's most doesn't lower (`GetEnemyCrushingBlowChance`); expertise, a
  raid boss dodges 6.5 % and parries 16.5 % (14 % in the text the sheet shows), a creature of one's level 5 and 5;
  armour, never past 75 %; a resistance, 0.75 × its points over five a level on average, so 75 % at five a level;
  the critical strike, weapons 100 % more, spells and heals 50 %; 14 attack power a point of damage a second, 10
  health a point of stamina and 15 mana a point of intellect past the first 20, 2 armour a point of agility, 20
  strength a point of block value; spirit's mana held 5 s after any spent, health 33 % faster seated. Most are in
  the sheet's grey notes, so in the card's « À savoir » already. Not in the game's files, from the original game and
  unverified here: the armour that gives 75 % (the game's own call can be asked for it, value by value), 102.4 % of
  miss, dodge, parry and block together against crushing blows, 315 of a resistance against a raid boss; no cap
  found for haste, the spells' power, health, mana or their regeneration.
  **What isn't known says so (Ikar 2026-11-19: "Put questio nmark icon to the characteristic currently unknown, no
  lying").** The game's own question mark (one constant, `Stats.UNKNOWN`; fishing's tooltip has the same: the ready
  check's « waiting » mark `UI-LFG-PendingMark` since 2026-11-19, square and drawn at 200 points, in place of the
  map's `QuestionMarkContinent-Icon`, a 20 by 27 marker drawn square, Ikar: "she is ugly, isn't there a betetr one
  ?") stands where a figure is missing or unchecked, and the card's foot says what it
  means (« le jeu ne donne pas ce chiffre, ou rien ne l'a encore vérifié »): in the amount's place for a source named
  without what it gives (a buff growing with its caster's level, an enchantment following its item's, a talent the
  data has no value of; under a skill's tooltip too), which showed nothing before; after a threshold nothing has
  checked: the weapons' hit against a raid boss and the dodge its expertise cancels (the Skills tab's 0.6 % at 300 of
  weapon skill may or may not be in the texts' figures), a resistance's 75 % (the original game's, no text of this
  one's); and a raid boss's parry, now on the card as the two figures the game gives, « 14 % ou 16,5 % », reached at
  the higher, what's short given for each. Not marked: the spells' hit, the defence, the armour, which the game's
  texts and sums state.
  **Since 2026-11-20 (Ikar: "questio nmark shoudl be present only when there is a question. And the description
  should give an answer"):** a mark only where the game leaves a question open, and each says its own, with what to go
  by, at the card's foot (and under a skill's tooltip, and fishing's), in place of the one sentence for all
  (`Stats.lua`'s `ask`, gathered while a card is made; `STAT_UNKNOWN_HINT` gone). What had a mark and has an answer
  now: a figure growing with its caster's level (202 effects: a druid's forms, a shaman's Rockbiter, Battle Shout,
  Blood Pact), written by `make_effects.py` as its sum with the spell's levels (SpellLevels, fetched since) and
  worked out as the server does at the character's level (Dire Bear Form 120 + 3 a level from 40, 180 at 60, 3 a
  level, the original game's); the thresholds of the enemy at hand and the raid boss's dodge, the game's own (its
  tables, its texts), with what the weapon's skill lacks of its most on top, 0.04 % a point as Forever's Skills tab
  works it out (`SkillsFrame.lua`'s GetHitDodgeParryChance; its 5.2 and 5.4 % the hit table's own at one and two
  levels), said as an answer under them, unmarked (« Votre compétence en Épées : 100 sur 115. Chaque point qui lui
  manque ajoute 0,04 % … »); no weapon of a skill in a slot, nothing short; the dodge in what would be, its agility's
  share followed point for point. Still marked, each with its question and its answer: a raid boss's hit with
  weapons (8 % in the texts, 9 % in the sheet's code; 27 and 28 % with two: aim for the higher), its parry (14 or
  16.5 %), a resistance's 75 % (the original game's most; this one's sheet counts on past it), a weapon's skill that
  can't be read, a source whose amount follows its caster's power or its item's level or a talent's rank the game
  doesn't give (« … : il est compté dans la valeur, sans son chiffre. »), the spirit's regeneration in what would
  be, a source more without a figure or a share without base in what would be, and fishing in a zone of Forever's
  own (« seul un essai le dira »). The defence's effects always as figures, either way of the level's most (Ikar's
  screenshot the same day, at 113 / 115: the sheet's sum stops at 0 below it, and its sentence said « 0.00% »): 0.04 %
  a point against an enemy of the character's level, its weapon skill five a level, the original game's rule, the
  sheet's own stated past the most alone; « -0,08 % » to dodge, parry and block, « +0,08 % » to be hit, at 113.
  **The card reviewed (2026-11-19, Ikar: "Do an in depth review of your latest changes").** Checked again against
  the sheet's code and this build's data: each text built with the sheet's own arguments (48 of them run through the
  card's cutting in French, the ones with notes in English, German and Spanish too); the defence's threshold its
  `GetEnemyCritChance`'s (five a level and 140); the fonts and the mark's atlas in the build; gear carries the
  all-kinds ratings only (item stats 31, 32 and 36; none of a melee, ranged or spell rating alone), so one stat a
  value is right. Four faults fixed, each with its test and its break: (1) the notes' grey was looked for at a
  paragraph's start, and in English, German and Spanish a raid boss's figures open on its name in red, so they went
  under « Effets », the 14 % parry with them; now a paragraph holding the grey anywhere starts the notes. (2) The
  card was as wide as its columns alone: a weapon's damage with its changes (« Main droite … (32 - 56 +4 x125 %)
  45 - 75 », no column) ran into its name; now as wide as its head needs. (3) A source known in part (one effect of
  a spell or one stat of an enchantment without an amount) showed its figure as the whole; it wears the mark after
  it. (4) Under a skill the mark came with no word of what it means; the tooltip says it. **Left open, not built:**
  (a) gear's « Équipé : » spells aren't named: 186 item and spell pairs in this build change a value of the sheet's
  (attack power 72, healing 22, spell power 21, mana in 5 s 12, ranged attack power 8, hit 6, critical strike 6…;
  `ItemEffect`, trigger 1), which `C_Item.GetItemStats` isn't known to give; where the game gives the changes' sum
  they fall under « Autres », elsewhere (hit, critical strike, haste, spell power, healing, penetration, mana in 5 s)
  they are missing with nothing saying so. (b) For those same values nothing checks the list against the value, so
  a list may be short unmarked. (c) The armour's 75 % and what's short of it are against one of the character's
  level, as the sheet's; against a raid boss it takes more, which the game's own call gives (level + 3), and the row
  doesn't say which it is. (d) A line without a figure inside a paragraph with one goes with it, and is dropped where
  figures replace the sentences (intellect's « vitesse d'amélioration de la compétence d'arme » for a caster, the
  block's « Augmenté par la Force »). (e) The game's own note repeats a threshold without the mark under the card's
  marked row (« 14,00 % de parer »). (f) Unseen in game: the card over its own folder's list (it stands above the
  row, over the rows above it), a source's name cut at 180 px, the 1 px lines at other scales, a card not drawn
  again while the pointer stays on it and a buff ends.
  **Those points ruled the same day (Ikar 2026-11-19).** Of (a): "Equipee are bonus from set no ? They shoudl show
  as a separate set bonus category, after equipement, could be in them, but near will simplify reading. Equipement
  et Set d'equipement". They are two things, and both now show. An item's own « Équipé : » spells are named, on the
  item's row with its stats: `make_effects.py` writes them to `Data/Effects.lua`'s `ITEM_SPELLS` (224 items of this
  build; `ItemXItemEffect`'s `ItemEffect` on equip), counted while the item is worn unless the spell shows as an aura.
  Built without the look in game the review asked for (he was away from the game): `C_Item.GetItemStats` reads an
  item's stats, not its spells, by all that's known of it; were it to give them too, a value the game sums would show
  a negative « Autres » by as much, which is what to look for. And the sources' rows are grouped as he asked: the
  base, what each attribute gives; then all the gear gives under « Équipement », slot by slot, an item's own armour
  and what it adds on one row (« 300 +20 »: asked what the second figure was, an item's extra armour beside its plain
  one, and offered one total in its place, "+30 is good, keep it"), its enchantment after it; next to it the sets' bonuses under « Ensembles
  d'objets », the game's own name for them (`LOOT_JOURNAL_ITEM_SETS`; its « Ensembles d'équipement » are the outfits
  of the equipment manager, so not his words); a line; the rest under « Bonus » (buffs, debuffs, talents, passive
  spells, what's left). A group's name carries its sum where each of its rows has an amount; a group of one row is
  that row alone; « Bonus » no longer carries the sum of all the changes, which the card's head has. Of (c), the
  armour's most against a raid boss: "yes": a second row, the game's own call at three levels above, and the first
  says its level (« Niveau 60, réduction maximale : 75 % », « Boss de raid, réduction maximale : 75 % »). Of (e),
  the game's note kept as it is: "agreed". Of (d): "go": a paragraph is read line by line, a line without a figure
  going to what there is to know. (b) stands, smaller now that the gear's own spells are named; (f) is his to look at.
  **Ideas from other addons (Ikar 2026-11-19: "See how we can enhance the addon, find insipiration online").** Read:
  the stat sheets made for Forever and the Classics (Forever Extended Character Stats, 13 407 downloads in two weeks,
  values alone; SinStats, its Forever beta, with the thresholds of a target of another level; StaticsDock and Simple
  Stats for the Burning Crusade, the second "built because SinStats has incorrect hit cap values"), the minimaps
  (SexyMap, BasicMinimap, MidnightMap), the data bars (XIV_Databar Continued, JulsanityUI, Djinni's, Titan Panel) and
  three guides to Forever's interface. No comment was readable on any page: feature lists and download counts only.
  Ten proposals put to him: (1) thresholds against what is fought now, (2) a card that stays open and follows, (3)
  only the class's own values in the folder, (4) a set's next piece, (5) a talents readout, (6) who pinged the
  minimap, (7) a style in the class's colour, (8) an Edit Mode layout offered once, (9) a layout shared as a text,
  (10) the weapons' hit as 8 % or 9 %. His ruling: "do 10, 1, 2. (even better, update with a different color on an
  item, talent, consumable hover), 4 Also, let's do a proper export and import." 3 and 5 to 8: no word, not built.
  Built the same day, 10, 1 and 4, rows of the kinds the card had:
  - *10.* The sheet's code has, in a table it doesn't read (`CharacterHitFrame_OnEnter`'s `meleeMissChances`: 5, 5.2,
    5.4 and 9 % for an enemy of the character's level to three above; `spellMissChances`: 4, 5, 6, 17), 9 % where its
    texts say 8 %. The card gives both, as a raid boss's parry: « Boss de raid, Mêlée : 8 % ou 9 % », reached at the
    higher, what's short of each, marked; two weapons 27 % or 28 %, the texts' 19 % more of either (mine).
  - *1.* Before a raid boss's rows, the enemy at hand: the target when it is an enemy of the character's level, one or
    two above (« Votre cible (niveau 25), Mêlée : 5,4 % »), else an enemy of the character's own level (« Ennemi de
    votre niveau (23) »): a lower target is no harder, a higher one is the raid boss's rows or further than the game's
    tables go, and a skull has no level. The hit from the two tables above, all marked, the sheet not reading them;
    the defence by the sheet's own sum at that level (five a level and 125), not marked; the expertise from
    `BASE_ENEMY_DODGE_CHANCE` (5, 5.5, 6 %), marked as a raid boss's; no parry, this build having no figure for it. The
    armour and a resistance, which the game works out for any level, say the target's row whenever it is of another
    level than the rows they have. Read when the card is drawn; it follows the target once the card stays open (2).
  - **Level by level (Ikar 2026-11-20: "met un lvl avec dans l'info box tous les lvl, la liste, comment, pourquoi";
    "Ou mieux, chiffre romain").** The enemy at hand gave way to the four levels the game's figures go to: I an enemy
    of the character's level, II and III one and two above, IV a raid boss three above (no V: the game has no fifth).
    Each under its numeral in gold and whom (« II Ennemi de niveau 24 », « IV Boss de raid, niveau 26 »; the target's
    level « · votre cible »), its rows each « quoi : chiffre — atteint / il manque … » (the hit a row a kind, the
    expertise its dodge and, where the game has a figure, its parry); then a weapon's skill short, the target's own row
    for one of another level (armour, resistances), « Comment : » (where the figures come from, and what the numerals
    are) and « Pourquoi : » (what reaching it does). Since 2026-11-22 those two are one line, « Comment, pourquoi… »,
    their text in the game's tooltip on its hover (Ikar: "crit hit defense and armor have disproportionate amount of
    text", then "hover to see details"): bronze on the card kept open, brighter under the pointer; grey on the
    hover's card, which the pointer can't reach (`StatCard.lua`'s `details`). The line wears after its value, in gold, the numeral of the
    highest level whose rows that count are all reached, each under it reached too: the hit by the kind of attack the
    line shows (`best`), the expertise by the dodge; none for one that reaches none. Worked out with the value, the
    armour's shortfalls left out for the line (`quick`: some fifty calls of the game's each).
  - *4.* Under the sets' bonuses, what the next pieces of a set worn would give of the value: each set's nearest bonus
    not had yet that changes it, named as the game names a set with its pieces, « Tenue de bataille (2/3) », the 3 the
    pieces that bonus takes (not the set's size, which the data doesn't hold; I had written « (2/8) »), grey with its
    figure and in no sum; also for a value nothing changes. On the card only, not under a skill.
  2 and the export were sketched first (his rule of 2026-11-19, a new look sketched before any Lua; the same page,
  its last rows): the card kept open by a click, drawn again as things change, and what an item, a talent or a
  consumable under the pointer would change, in another colour (A, one light blue for what would be, the figure it
  replaces greyed before it: mine; B, the game's green and red); an export and an import of the settings as a text.
  Of the sketch's foot, which said a click on the attribute let the card go ("quelle attribut ?"): "just keep the
  cross, and escape should close it too". **The card kept open, built the same day:** a left click on an attribute
  keeps its card open and no longer opens the character sheet (mine: its key does, and the click had to be the
  card's); a second card (`KaLiHUDStatCardPinned`), where the hover's stood, over the game's windows and under its
  tooltips, moved by a drag; one at a time, a click on another attribute making it that one's (mine, to start); no
  hover's card beside it for the same value; drawn again each time the values are read again (the sheet's events)
  and when the target changes; shut by the game's own cross on its corner or by Escape (`UISpecialFrames`), after
  which nothing draws it. No « Épinglée » word on it as the sketch had: the cross says it. Its place isn't kept from
  one time to the next.
  **What would be, built the same day.** Of the two colours: "go for the light blue, we will tackle profile next"
  (so A; the export and import wait for that talk about profiles). While a card is kept open, what the game's
  tooltip shows is tried on its value (`TooltipDataProcessor`'s post calls for an item and for a spell, the
  tooltip's `OnHide` to stop): an item that could be worn, in its slot (a ring's, a trinket's, a one-handed weapon's
  first; a two-handed weapon empties the off hand; one worn already, nothing), with its enchantment, its
  « Équipé : » spells, the sets' pieces counted again and the weapon's oil gone with the weapon; a talent, at its
  next rank (its first for one not bought, nothing at its last); a consumable, its spells as buffs more
  (`Data/Effects.lua`'s `ITEM_USES`: `ItemEffect` on use), nothing while the buff is on. A meal at first wore the
  question mark alone, its buff not being its use's spell ("wait, why meal does not work ?"): eating is the use's
  spell, and gives the buff after a while by one of its effects (`SpellEffect`'s `EffectTriggerSpell`). The generator
  now follows what a use gives rise to, twice at most: 589 items against 408, 164 of this build's 341 meals and
  drinks against 39; of the 177 left, 172 trigger nothing, 4 a spell with nothing for the sheet, none goes a third
  step: they change nothing, and the card says nothing of them. A consumable's amount is the data's, of a buff not
  had yet (an aura's is the game's own): the figure is given, unmarked, since 2026-11-19 (Ikar, of an elixir's
  « +50 ? »: "and what is the questio namrk for here ?"; of the meals' kept marked a moment: "never seen a random buff
  are you sure about that ?"). The data gives a figure only where it is the buff's own whoever has it (no level, class
  or power in it), and no buff's is random (`Variance` 0: a meal's « Bien nourri », spell 1248420, +1 agility, reads
  as an elixir's does); the question mark stays where it gives none. Worth a look in the game all the same: 89 of
  the meals' buffs read +1 or +2
  of an attribute in the data (« Kébab de loup assaisonné », spell 1248420: +1 agility), no field of the data scaling
  them, which is either Forever's own small buffs or an amount worked out somewhere this doesn't read. The value's
  sources are read a second time with it in place (`WOULD`, through which the gear's links, the attributes and the
  talents are read), each attribute first, so that what stands on one follows (10 of agility, 20 of armour). The
  card's head: the value as it is, greyed, by how much it would change, an arrow, what it would be in the light
  blue (`7fd4ff`); its rows: one that would come in the light blue, one that would go greyed with its figure down
  to 0, one that would change with both figures; the base and « Autres », what the game's own sums leave over, as
  they are. The sum is the game's own order: the base and the parts named of it, the shares of the base, the flat
  changes and what is left over, the shares of the whole.
  Its limits, mine, to rule if they matter: the head and the sources alone follow (« À savoir » and « Effets » keep
  the value's as it is, where the sketch had them follow); a weapon's damage has no sources, so nothing is tried on
  it; the dodge and the regeneration wear the question mark when the agility or the spirit would change, the game
  giving their share at the value now alone; an item's effects on use or on a hit aren't counted, nor whether the
  character can wear it; a second ring or trinket is never tried in the second's place. **To see in the game,
  nothing of it having been:** that an item's tooltip hands its link to the post call (else the tooltip's own),
  that a talent's tooltip in Forever's talent pane is a spell's (if it isn't, nothing shows for talents), that an
  item's stats are had from its link while it lies in a bag, and the card 80 wider while two figures share a row. On profiles, his question the same day ("I remember a
  lot of addon work based on profile, why ? often confusing, is that some kind of unified system ?"): they are
  AceDB's, a library most large addons embed, not the game's; KaLi HUD has none and keeps one set of settings for
  the account, which an export and an import carry between accounts and players.
  **Dispositions, proposed, not ruled (Ikar 2026-11-19: "ok, about import / export. More globally, we should have to
  duplicate from another alt too. Maybe save/update/create custom preset in the edit mode ?").** Today everything is
  the account's (`KaLiHUDDB`: options, items, folders, macros, separators, status places), so an alt has nothing of
  its own to duplicate, and a « Préréglage » is a style, six values of the look. Put to him on a sketch (the same
  page, its last two rows): one list of named setups, « Disposition », first row of KaLi HUD's Edit Mode dialog, in
  the game's own words and shape for Edit Mode's layouts (the account's or « propre au personnage », new as a copy of
  the one in use, copy, rename, delete, « Partager », « Importer »); a disposition holds all that is set in KaLi HUD,
  never a character's gold nor a session's measures; each character remembers its own, all on the account's « KaLi
  HUD » at first, which is today's behaviour; another character's is taken by « copier » on its row; changes go into
  the one in use at once, as now; an import makes a new disposition and changes nothing until it is picked, so no
  parts to tick nor undo; « Style » stays the look alone. Not KaLi HUD's settings hung on Blizzard's own layouts:
  their export can't carry ours and a rename there would lose them. No Lua until he rules.
  **Looked into further ("Do some more reasearch on what is the prefered approach, what is the best"), read on
  2026-11-19.** What players ask for is one setup for all their characters without doing anything: in two Blizzard
  forum threads on it (2022, 2025-2026) four posters want that and none wants each character apart; « Account Wide
  Interface Settings », which exists to make per-character settings the account's, new characters included, has
  676 164 downloads and a Forever file; TheOneProfile ("Make all your addons use one global profile on all
  characters"), SimpleTitanCompanion (Titan Panel kept the same from a main), UI Passport, WowSync, Account UI
  Profiles and ProfileManager (10 889) are all made for the same want. The confusion of addon profiles is AceDB's
  default: with no default named, "each character defaults to its own profile", so a new alt starts bare; Postal's
  author, asked in 2023 for one shared by default, agreed it "would be best" and added it (4.0.0); Skada shares one
  by default. The game's own way is the same wherever it has one: the account's unless ticked « propres au
  personnage » (key bindings, a checkbox; macros, « générales » and the character's; Edit Mode's layouts). Edit
  Mode's layouts themselves draw complaints: a character's layout doesn't show on another character, five of each
  kind at most, a save that doesn't take, layouts gone after a patch; and an addon's author found Blizzard rewriting
  its list on each save. Sharing is a text everywhere (ElvUI, Plater, Edit Mode, wago.io), an import that becomes
  one more named thing (Plater's) being the safe form; the newer tools capture a setup and apply it elsewhere, with
  an undo point at each apply (WowSync). The evidence is thin on one point: nothing compares a list of live named
  setups with saved copies; that part is my judgment.
  **What that changes in the proposal (the sketch redrawn, the first kept beside it as the alternative):** the
  settings stay the account's, live, as today; one switch, « Réglages : du compte / propres à <personnage> », the
  key bindings' own, gives a character a copy of its own and takes it back; a « Préréglage » becomes what he named,
  a copy saved under a name of all that is set (save the settings as they are, apply, update, rename, delete,
  share), with the other characters' own settings in the same list to take from, and the settings as they were
  kept in it at each apply, which is the undo; an import adds a preset and changes nothing until applied; the nine
  looks stay under « Style ». Fewer notions than a list of live setups each character points at, which is AceDB's
  shape and Edit Mode's, the two that players trip on. Still his to rule; no Lua.
  **Where it goes (Ikar 2026-11-19: "ok, but this should go into the setting windows, not the edit mode. Also, see
  options in the edit mode, should some go to the settings instead ?").** So the shape is taken, and its place is
  KaLi HUD's page in the game's options, not the Edit Mode dialog. Of the dialog's forty-odd rows, put to him on the
  sketch redrawn as that page: Edit Mode keeps what is set while looking at it (shape, size, colour, place: the
  style, the plate and its reach, borders and backgrounds, margins, the map's ring, header, day ring and zoom
  buttons, the cartouche with its size and lift, Blizzard's bar art hidden, each status bar whole by his rule of
  2026-11-15, the info bar's text size and spacing); the page would take what KaLi HUD does and which of its parts
  are on, as the game's own options hold which action bars are on and Edit Mode where they go. To move, mine to
  propose: the four parts' switches (`plate`, `minimap`, `windowFold`, `infoBar`), the least sure, a part's switch
  being also at hand where it is tuned; behaviour (`minimapAutoZoom`, `rotateMinimap`, which is the game's own
  setting shown again, `chatPeekOnType`, `meterUnfoldCombat`, `folderCombatClose`, `hideExternalXP`); sounds and
  animation (`foldAnim`, `foldSound`, `folderSound`); and `slotsLocked`, in both places today, in the page alone.
  **Ruled the same day.** Of the four parts' switches: "keep 4, but duplicate in the settings too": in the Edit Mode
  dialog as now, and in the page. Of « Tourner la minicarte », which the game's own options have: "drop the
  minimap" (read as that row, his answers following the questions' order: mine to confirm). Of « appliquer »:
  "appliquer shown when ? Ideally I will have a checkbox for each state, on by default": a click on a preset opens
  it, with a box for each part of it, all ticked, what is unticked staying as it is; the list's rows carry names
  alone, and « Mettre à jour », « Renommer », « Partager », « Supprimer » are in that window. The parts, mine to
  propose: the look (style, borders and backgrounds, cartouche); the plate, margins and minimap; the status bars;
  the info bar (elements, folders, macros and notes together, a folder's macros going with it); behaviour and
  sounds. A preset always holds all of them; the boxes choose at apply. Of the looks' row: "and yes, yo ucan rename
  to style". The behaviour, sounds and padlock rows moving to the page: no word against, taken as agreed, said to
  him. Of a window of our own for all this ("Shoudl we have out own setting window ? Or keep using wow one ?"): the
  game's, said to him with why (where players look; the page in it is the addon's own frame already; Edit Mode's
  dialog is the window of our own where one is needed); then "Ok, go for implementation."
  **Built the same day, in four steps, each checked before the next.**
  - *The options' pages.* The game's options show an addon's page 602 high and don't scroll it, so KaLi HUD has
    three, none taller: « KaLi HUD » (the way to Edit Mode, the four parts' switches, the addon's state and a bug's
    report), and under it « Préréglages » and « Comportement et sons » (the auto zoom-out, the chat shown while
    typing, the meter unfolded in a fight, folders shutting in a fight, the other experience bars hidden, the
    padlock, the bags' free slots, the gold's copper; the fold's animation and sound, the folders' sound; a reset
    for the page). Since 2026-11-20 (Ikar: "some settings shoudl be a component option in it right click instead of
    a addon option"; "Diagnose can be removed, it is i nthe report bug"): the bags' free slots and the gold's copper
    only in their own right-click (`UI/Hub/Items.lua`'s menus, where they already were), the padlock only on itself
    and in the bar's menu; the addon's state no row of its own, the bug report carrying it; the report window's two
    buttons « Sélectionner le lien » and « Sélectionner le rapport », in the three addons ("Report bug button should
    say select texte, not copy, they do not copy": they select, the player's Ctrl+C copies, which the hint then says).
    `shared/addon/Page.lua` learnt a slider's and a choice's rows, and to draw its rows anew. The
    Edit Mode dialog lost those rows and the minimap's turning; its looks' row is « Style ». A row's name has less
    room on a page than in the dialog (195 wide, one line): four of them are shorter now, their tips unchanged, and
    the window fold's and the info bar's switches have a short name on the page. `tools/kali/labels.py` checks the
    pages under an addon's page too.
  - *The settings, the account's or a character's own* (`Core/Sets.lua`, `Core/DB.lua`). The file keeps the
    account's settings where it always did; a character's own under `chars`; while one plays on its own they stand
    in the settings' place and the account's wait in `account` (`live` naming whose), put back as the game writes
    the file (`DB.Leave`, in `BeforeSave`) and as a file written without that opens. So nothing that reads the
    settings changed. Ticked, « Propres à ce personnage » makes the settings in use that character's where they
    stand and keeps a copy as the account's: nothing is drawn again. Unticked, the account's are applied whole and
    its own kept as a set (« Réglages propres à <nom> »).
  - *Sets.* A set is `{ name, at, by, settings }` in `presets`, the settings copied whole (`DB.SET_FIELDS`: options,
    items, folders, macros, separators, copies, the minimap buttons left to their addons, the status bars' places,
    what was made once, « Suite »); ten at most. Applying copies the parts ticked into the tables in use, row by row, through
    `History.Replace`: done whole or put back, the pieces told as an undo tells them, the bar's own steps to undo
    forgotten (steps of what is no longer there), then the whole HUD drawn again; refused in a fight, the bar's
    buttons being the game's protected ones. The five parts: the look; the plate, margins and minimap; the status
    bars and their places; the info bar with its elements, folders, macros and notes; behaviour and sounds
    (`Sets.PartOf`, an option this build has no default of being an element's own). What the settings were is kept
    as a set at each apply (« Avant « <nom> » »), the last three. Any settings taken from elsewhere go through the
    file's own repairs first (`DB.Repaired`).
  - *The page and a set's window* (`UI/SetWindow.lua`). Since 2026-11-19's evening (Ikar, of the list a button
    opened and the window that held the rest: "vos prereglage can't be a drop down with button in it own section ?
    Grayed when innactive"): « Réglages », the box above (since 2026-11-20 in one section with the settings as they
    are, first, « Réglages actuels »: the box, « Enregistrer… », « Partager… »; Ikar: "the first checkbox and the two
    (save and share) should be combined into one"); then a section « Vos préréglages »: a dropdown,
    « Préréglage », the sets, the other characters' own settings under « Reprendre des réglages » (« Réglages de »
    and the name, by their key) and the settings as they were under « Sauvegarde », « Choisir… » while none is picked;
    under it its buttons, three a line, « Appliquer… », « Mettre à jour », « Renommer », « Partager… »,
    « Supprimer », each greyed while nothing is picked or the one picked doesn't allow it (another character's
    applied and shared; the settings as they were applied, shared and deleted; a set all five); « D'un texte
    partagé », « Importer… ». A section « Réglages actuels »: « En faire un préréglage », « Enregistrer… », a name
    asked, the set then picked; « Partager vos réglages », « Partager… ». A set imported is picked too. Bringing up to
    date and deleting are asked first. « Appliquer… » opens the set's window, which applies alone now: when it was
    saved and on whom, a box a part, all ticked, the look's with its style and the info bar's with what it holds,
    the game's macros it names that this character hasn't, « Fermer » and « Appliquer », greyed with nothing ticked.
    The family's page (`shared/addon/Page.lua`) has for it a row of buttons (`buttons`), a button greyed with its
    name by its `enabled()`, a dropdown's group titles and dividers and its text while none is picked (`empty`).
  - *As a text* (his "let's do a proper export and import"). `KaLiHUD:1:` then the settings and the version that
    wrote them, by the game's own `C_EncodingUtil` (CBOR, deflated, base 64): no library. Read back, a text that
    isn't one, one cut short and one a newer version wrote are told apart and said in the import's window, which
    stays; spaces and line breaks a chat put in are passed over; its settings are repaired as the file's. One that
    reads is kept as a set under a name asked for and opens: nothing changes until it is applied. Shared, the text
    shows selected in the family's text window. **Since the same day** (Ikar: "the export, it is quite convoluted to
    export": the settings had to be kept as a set, found in the list, opened, « Partager » clicked, then copied out of
    a debug window that said nothing of copying, eight steps): the settings as they are shared in one click from the
    page, « Partager vos réglages » (`SetWindow.ShareCurrent`, kept as no set), or `/kh export`; `/kh import` opens
    the import. Shared, the text is in the import's own window, which works both ways: its title « Partager : » and the set's name,
    « Déjà sélectionné : Ctrl+C pour le copier. » over it, the text selected and focused, kept whole and selected
    whatever is typed or clicked in it, and Ctrl+C (Cmd+C on a Mac) shuts it once copied, a chat line saying so
    (« Copié : collez-le où vous voulez »), Escape or « Fermer » too. A set's own « Partager » opens the same.
    **To see in the game:** that Ctrl+C copies before the window shuts (it shuts on the key's release, the copy being
    on its press).
  Mine, to rule if they matter: three pages where the sketch had one; the padlock, the bags' and the gold's boxes on « Comportement et sons »; ten
  sets and three backups at most; « appliquer » on another character's settings takes them as they were when that
  character last logged out. **To see in the game, nothing of it having been:** the three pages' height and the
  slider's and the drop-downs' place on a row; a set applied with folders and macros in it (the secure buttons made
  and unmade outside a fight); the import's box taking a long text pasted; `C_EncodingUtil`'s text there and back.
  **A raid boss's parry, looked into (Ikar 2026-11-19: "check about the boss parry. Investigate as much as needed"):
  not settled, by anyone.** The client has three texts and no figure in code or data: `CR_EXPERTISE_TOOLTIP` (melee)
  and `CR_PET_EXPERTISE_TOOLTIP` say 16.5 %, `CR_RANGED_EXPERTISE_TOOLTIP` 14 %, the same in all eleven languages and
  in every build from the first beta (1.60.1.69876, 2026-09-16) to the latest (70959, 2026-11-17; wago.tools). The
  pet's text came later (between builds 70245 and 70532) and says 16.5 % again, so that is what Blizzard last wrote;
  the sheet itself shows the 14 % one, its code asking a `category` nothing sets
  (`PaperDollFrame_ExpertiseOnEnter`). `GetEnemyParryChance`, in the sheet's file, is the modern game's and nothing
  calls it (its table −1.5 to 3 %). 14 % is the original game's figure, which Blizzard confirmed for Classic; but
  Forever's own Skills tab works weapon skill at 0.04 % a point of hit, dodge and parry against a level 63 boss
  (`SkillsFrame.lua`), not the original's rule, so its figures can't be taken for Forever's, and a character at 300
  of skill is shown −0.60 % there, which the texts' 8 % and 6.5 % may or may not hold already. Outside: no figure
  from Blizzard, no test (the raids open on 2026-12-09; the guides quote the same two texts, most keeping Classic's
  14 %). What would settle it: swings from the front counted against creatures three levels above, some two
  thousand to tell 14 from 16.5 %; the combat log's events are in this build (`COMBAT_LOG_EVENT_UNFILTERED`,
  `C_CombatLog.IsCombatLogRestricted`), whether an addon reads them in a fight not checked.
  **Settled (the probe of 2026-11-19 20:26):** Ikar, "defence I get +6 from bracelet but it is still writen
  (enchantements), why ?": no enchantment worn gives defence. The defence's bonus was the main hand's, its random
  suffix: « Écrasante de défense », `UnitDefenseSkill` 108 +3, and `C_Item.GetItemStats` on its link gives
  `ITEM_MOD_DEFENSE_SKILL_RATING_SHORT` 3, the suffix's stats read with it. Its row was the item's, alone, named
  without anything saying it was an item (Ikar: "Unclear"): its icon and « Équipement » over it since.
  The game hides attributes from addons during a fight (`SecretWhenUnitStatsRestricted`, read through `ns.Plain`):
  each keeps its text, read again after; one never read yet (a reload in a fight) its name and a dash. Health
  regeneration has no call (TitanRegen measures it), so none.
- **Reagents** (a class's, Forever's item ids checked) and **ammunition** (hunters, rogues, warriors): counts only.
- **Junk** (the grey items' worth; the vendor's own « Vendre toute la camelote » sells them), **currencies** (those the
  player shows on the backpack in the game's window: its choice, nothing saved), the zone's **PvP state** (the
  minimap's words and colours, the crossed flags greyed then tinted: Ikar "with different color icon for type"), the
  zone's **levels** (Forever's Group Finder's, `Data/Zones.lua`: see the skills above; coloured by difficulty), **today** (the calendar's events and invitations,
  its month's data asked once at login as its button does), the clock's **alarm** (« Alarme activée » or « désactivée »,
  as the clock's window words it), the game's **stopwatch** (its menu starts a countdown).
- **Guild** (members online, their list in the tooltip; whisper or invite from its menu; a list of people is never
  items in a folder, which would reshape on its own and can't resize in a fight), its **message of the day** (an
  announcement's exclamation mark), **friends** online.
- **Group** (Ikar: "group and raid tool, all in a folder"): the loot rule and threshold, dimmed out of a group; the
  difficulty, « Réinitialiser toutes les instances » in its menu; the ready check, a 10 s countdown and the eight world
  markers and their clearing as macros of the game's own commands (the secure ones a macro may run). The markers in the
  raid menu's order, the skull first (`WORLD_RAID_MARKER_ORDER`), each named and drawn as its sign's raid target
  (`WORLD_MARKERn`: `/wm 1` the blue square; the raid frame's `GM-raidMarker` of 9 less the sign); « /cwm tous »
  clears them all (the command compares with the game's `ALL`).
- **Session** (Ikar: "session (folder, add open the cooldown settings tool)", "timer (session and afk)", "errors, maybe
  enhance it"): time since login and away, the session's errors (the Lua errors BugGrabber caught, LibsAddonTools
  carrying it and taking `seterrorhandler` from anyone else, and the actions the game blocked, any addon's; a click
  opens the error display's own window), then macros: `/reload`, the cooldown manager's `/cdm`, log out, quit (secure
  commands: no addon may call `Logout()`, a macro may).
- **Statistics**: achievement points, deaths (this session; in all, the game's statistic 60), and the game's
  statistics by id, each named by the game, one it doesn't know nowhere.

**The bar's own menu** (right-click on the bar or the padlock): the lock, Edit Mode, then the elements by category
(a folder, a macro or a note made from it goes where the menu was opened, as a drop there would put it,
`HubDrag.PlaceAt`, and a folder made from an element's menu takes that element's place, the element in it; Ikar
2026-11-20: "it shoudl appear where the user put it., not on the right")
(Folders, World, Time, Character, Attributes, Skills, Social, Group, System, Minimap, Other addons; the macros
left out since 2026-11-20, Ikar: "the emote huge list when you right click on the bar. The whole emote category shoudl
go, keep only the folder": a macro is deleted, never hidden, and « Emote » stays among the folders;
`obj.category`, natives' Minimap, other addons' last; separators none), each sorted,
a tick for shown; unticked it's hidden, ticked again it goes back to the side it left (`item.last`). Where each goes
is in its own menu (its right-click), not here.

## The status bars

Two, « Barre de progression 1 » on the left and « 2 » on the right, along the info bar under the bars taken, as
SpartanUI's, drawn and filled as FlareUI's XP bar (Ikar 2026-11-14: "Flare XP bar looks much better... with all its
features"; its code is MIT, adapted; its art isn't, our textures are
ours): a dark ground and a glazed track under the fill; the fill gliding forward only (`ExponentialEaseOut`), towards the
map unless reversed, Blizzard's blue once rested, the rested bonus ahead of it in light blue; a flash on each gain; 5 %
bubbles; outlined numbers as values, percentage, both or what's left, on hover or
always; the percentage filled in an end cap at either end or none (below); every setting each bar's own (below); the
tooltip with the level, what's
left, the rested, the XP an hour and the time to the level; a reputation's standing (paragon, renown and friendships as
Blizzard's bar reads them; at the top only its name), honour with its level. Each
side shows experience, the watched reputation, honour or nothing, experience on the left and the reputation on the
right by default; the automatic choice FlareUI's makes is gone (Ikar 2026-11-15), a saved `auto` back to the default.
The quests' XP ahead of the fill in gold is gone (Ikar 2026-11-15: "not very useful"). Not taken:
FlareUI's pip between its two halves (ours stand apart), its font and border choices (ours are the HUD's), its fading.
FlareUI's own XP bar and Blizzard's are hidden meanwhile
(`hideExternalXP`): alpha 0 on `FlareUI_XPBar` and on `StatusTrackingBarManager`, which holds both of Blizzard's bars.
Alpha 0 leaves a frame's mouse on, so every frame under them that takes it (Blizzard's bars, the rested tick, a button
in MEDIUM over the info bar) is made deaf while they're hidden and given it back after (2026-11-15). Their Edit Mode
boxes ignore their parent's alpha (`ignoreParentAlpha`): they stay seen and Blizzard's, so without FlareUI Blizzard's
two boxes still show in Edit Mode. FlareUI's XP bar keeps Blizzard's hidden anyway (a state driver, which hides the
boxes too) unless its own switch is off.

- **Every setting each bar's own (Ikar 2026-11-15: "Make all the setting local to each bar. And rename Barre de
  progression 1 and 2").** No shared section left in the Edit Mode dialog: each bar's own, « Barre de progression 1 »
  (the left one) or « 2 », holds what it shows, its cap's end and shape, its fill, its texture (`statusLeftTexture`,
  `statusRightTexture`), its bubbles (`…Ticks`), its text's size (`…FontSize`), its width (`…Width`), when its text
  shows (`…Text`), its numbers (`…Numbers`) and « Replacer » for it alone. « Masquer les autres barres d'expérience »
  (`hideExternalXP`) isn't a bar's: one setting, shown in both. The settings a file holds from when they were shared
  (`statusFontSize`, `statusNumbers` and the rest) go to each bar that has none at load, then are gone (`DB.Open`).
  Its name (`StatusBars.Name`, « Progress bar 1 » in English) is its section's, its menu's title and its Edit Mode
  box's; the right click sets its own. The "Barre de progression" Ikar names isn't the game's: Forever's French calls
  Blizzard's own « Barre d'état 1 » and « 2 » (GlobalStrings, build 70938).
- **One size (Ikar 2026-11-15: "unify its size with the text size, no need for 2 options").** A bar's
  `statusLeftFontSize`/`statusRightFontSize` (« Taille » since 2026-11-15, « Taille du texte » before; 6 to 16; 8 until
  Ikar asked "can we go thinner than 8?") is its text's size; its box is 3 taller, its end cap 4 more, its slot the
  cap's height (the box's without
  one); along the info bar both on the taller slot's middle line.
  `statusHeight` is gone; a saved one stays in the file, unread.
- **The end cap (Ikar 2026-11-15: "can you make the end a bit better? Bright color? Like a cartouche, a nice end
  cap?").** The percentage (Ikar's "label") in a cartouche of its own over the bar's end, 2 taller than the box each
  way: its border the plate's metal (`BandKaLi.tga`) at 0.35 of its depth (half until Ikar: "reduce
  the border on the cap") and 1.2 times the border's colour (`Border.CapProfile`, `Border.CAP_SCALE`,
  `Border.CAP_SHADE`), its ends whole as its shape says (round: a pill; bevel: pointed; square), inside the bar's
  colour lit from the top as the plate's background (`Border.Tint`; `Geometry.Slabs` fills the shape with quads, its
  edge under the metal). As wide as two digits ("100 %" widens it while it shows) and its ends, which reach as far as
  their shape needs to keep the digits' corners (Friz's ink, 0.76 of the size) half a unit inside the metal
  (`Border.CapEnds`; Ikar: "and the width"; it was the widest percentage and half its height each end). Round and square
  ends get 0.2 of the text's size more each way (`StatusBars.CAP_ROOM`): they hugged the digits, half a unit off the
  metal at the text's middle line where a pointed one leaves about 3, and the percentage looked off to the right in
  them (Ikar 2026-11-15; inferred: the text's pixel snapping shows in so little room). The box runs
  under it to its middle, the track under its metal; it takes the bar's hover and right click. Its first form, the same
  morning: a label inside the bar's border past a divider ("in the same border"), which Ikar found plain.
- **Per bar (Ikar 2026-11-15: "where we see the cap, right left, or none, per bar, and type of cap. Also, make some
  bars fill in reverse. By default, they both fill in the direction of the map, cap on the map side").** Each bar's
  cap at its right or left end or none (`statusLeftCap` "right", `statusRightCap` "left": the map's side), its shape
  pointed, round, square or the corners' (`statusLeftCapShape`/`statusRightCapShape`, "auto"), its fill towards the map
  (the left bar's from its left end, the right bar's from its right end, `SetReverseFill`) unless reversed
  (`statusLeftReverse`/`statusRightReverse`), the rested bonus from the same end. `statusLabel` is gone. In its right
  click menu (an « Embout » submenu, « Cartouche » until 2026-11-20, the windows' fold art's word too; « Remplissage
  inversé ») and in its own section of the Edit Mode dialog,
  which a click on its Edit Mode box opens.
- **Centred text (Ikar 2026-11-15: "seems not perfectly centered").** Inferred, not measured in game: a font string's
  line is its size tall from the font's ascender down, which leaves Friz's digits 0.1 of the size under its middle; the
  percentage and the bar's text are lifted that much (`StatusBars.LIFT`), as Blizzard lifts its XP bar's text, the same
  font (`TextStatusBarText`: Friz 10, outlined), by 1 (`StatusTrackingBarTemplate`).
- **Colours (Ikar 2026-11-15: "make the colors less saturated, a bit darker").** The game's colours (experience,
  rested, reputation, honour) drawn at 0.7 of their saturation, towards their own grey, and 0.85 of their light: the
  fill, the rested bonus and the end cap; the tooltip keeps the game's.
- **Where they stand (Ikar 2026-11-15: "make it movable, with given width"; then "by default, they should sit like the
  one on the left, not the default position shown on the right").** Along the info bar under the bars taken each side
  of the dome, from the map's ring, the bar's inner end straight under the ring's side (`dome.ring`, where the carved
  neck under the map begins), out to those bars' far end, or the bar's own width from the map outwards (0, the
  slider's left end, is Auto); 3 above the info bar (`Geometry.GAP`). That's where Ikar had dragged his left bar (his
  probe: its end 0.9 further in, 0.2 lower); before, they stopped 5 outside the dome's side (`dome.r`) and stood 5
  above the info bar, so a cap could touch the action bars over it. In Edit Mode each wears a box as Blizzard's frames do
  (`EditModeSystemSelectionTemplate`): a click opens the
  dialog at that bar's own settings, a drag moves the bar under the pointer, the plate following live; let go, it stays
  (`KaLiHUDDB.statusPlaces.left`/`right`: its bottom left and the width it had, used while the width is Auto), a frame
  the plate takes within reach as any other (`StatusBars.PlaceMoved`, before `Geometry.Cover`), free out of it. The row
  along the info bar counts only the bars still in it (`StatusBars.Heights`, `RowHeight`). « Annuler les
  modifications » puts the places back with the settings (the dialog's `extra`); a bar's « Replacer » lays it along
  the info bar again. One place for every Edit Mode layout.
- **Their border** is the thin one at 0.8 of the border's colour (`Border.THIN_SHADE`, the folders' panels too). Ikar
  2026-11-15: "too bright"; measured, its metal was 1.25 times as bright as FlareUI's XP bar border on average
  (`FlareUI-Thin.tga` in CC9957 against `BandThin.tga` in d6b386, alpha-weighted luminance), now level with it.
- **Numbers:** the thousands separator is a no-break space (U+00A0), as the game's own French strings use; the narrow
  one (U+202F) showed as a square, the game's fonts lack it (Ikar 2026-11-15).

## The minimap and unified slot hub

- **Minimap (`UI/Minimap.lua`).** Forever's own coordinates under the map (`MinimapContainer.PlayerCoords`) are
  off while the HUD has the map (Ikar 2026-11-19: "it still show the coordinate bellow, when taking over, we should
  hide them", "there is a option in forever to disable it"): the game's setting for them, `minimapShowPlayerCoords`,
  turned off as it takes the map, the player's value kept in the saved `cvars` (`DB.KEPT_CVARS`) and put back as it
  gives the map back; Blizzard's code then leaves them empty, whoever styles or fades the frame (FlareUI). Ticked
  again meanwhile, the setting stays as the player set it. Put back at each logout too (a reload's), the value kept
  marked `:back` and taken again at the next login (the review of 2026-11-23: disabled or removed, the HUD had left
  them off); whether the game keeps a setting changed at a logout isn't known, so still the HUD's 0 at the next login,
  the value kept stands. The info bar's « Coordonnées » shows them instead.
  Owns `MinimapCluster` cleanly without depending on FlareUI: keeps Forever's crisp
  engraved compass ring (`UI-HUD-Minimap-Frame` / `-Pointer` + `-Circle` when rotated) by default (`minimapRing =
  "blizzard"`), or our border round the map (`"kali"`), or `"none"`, named « Blizzard classique » (Ikar 2026-11-15):
  the plate's own recess and bronze lip round it; or one of 17 rings from Ikar's own art (Lava added 2026-11-18, below; the Steampunk one his own since 2026-11-20, below; the others picked 2026-11-16, on
  `bench/minimap.html`, his names: Forest, Black steel, Blue steel, Fire, Golden, Mage, Rune, Steel (shown as Silver since 2026-11-16, Ikar: "rename it to silver"), Steampunk (1 and 2 until 2026-11-20),
  Arcane, Nature, Frost and Fire crystal, Gem, North star, Astronomy), listed after the plain three under their themes
  ("Group them by theme": metal, elements, magic, clockwork, crystal, sky; a `{ title = … }` in a choice's values is a
  menu title, `Shared/Dialog.lua`). `tools/cut_rings.py` cuts them out of his sheets (`art/minimap`), keyed against
  each cell's ground; a ring painted inside (Stars 2, 3, 5: a nebula, constellations) has that ground taken out of each
  texel there instead, so the paint lies over the map see-through, its lines and stars solid ("the partial opacity of
  star 2, 3 and 5"), its map's edge where its band is solid most of the way round; a neighbour's ring reaching into a
  cell is cleared by its fitted disc, the star sheet's cells taken 40 texels wider (Star 1 runs past its fifth), a texel
  between the two going to the ring whose outer edge is nearer (cleared off the ring's band alone, Star 1 lost its rim
  over a fifth of its right side). A ring painted a little oval is squeezed round along its long axis (Ikar 2026-11-16:
  "it seems not all are perfectly round ... the full art is not a circle, doesn't have to be, but there is a circle"):
  its band's two edges fitted as one ellipse, each edge's points dropped only on the side ornaments and shadows push it
  (out for the outer edge, in for the inner); the crystals were 2.4 to 4.7 % wider than tall, the gears 2, the metals 0.3
  to 1.4, Blizzard's round. Not squeezed, a ring whose two edges don't agree on its shape to within 2 % (North star and
  Astronomy: the shadow they cast below lies in the hole at the top and outside at the bottom, and alpha alone can't
  tell it from the band) or whose inside is painted. **Fire is Ikar's own art since 2026-11-18** ("Added a new minimap
  art. That shoudl replace fire."; the volcanic ring of his first sheet before): one ring alone on a blue ground
  (`art/minimap/rings-5.jpeg`), whose edges the key left blue, a rim of it solid (a texel 40 off the ground still more
  ground than art); on such a ground (`TINTED`) each texel within 5 of it takes the colour of the art just inside and,
  for its alpha, the share of that colour it holds over the ground, so the edges are the ring's dark iron, soft, and
  no blue shows. Its id stays `fire`, so whoever chose it has the new one. **Lava**, the elements' third (Ikar
  2026-11-18: "downlaoded another one, laya, add it as a new minimap"), dark rock with glowing cracks on a ground as
  dark as its stone (`art/minimap/rings-6.jpeg`: the rock lies 4 to 8 off it, so a colour key would see through it),
  is cut by its shape (`CIRCLE`): its two dark outlines, what stands 15 off the ground, met along rays and fitted as
  circles, the band between them kept whole, the soft shadow round it left out. **Steampunk is Ikar's own art since
  2026-11-20** ("I have a new steampunk minimap art that will replace the 2 currently in the plugin", then "you didn't
  update the steampunk minimap"): one ring alone on white (`art/minimap/rings-7.jpeg`), a rail with a compass rose on
  top, lit tubes and gauges either side, gears and valves below, its pale gauge faces kept by the key; in place of
  both Steampunk ones (`rings-3`'s second and third), its id `steampunk`, the Steampunk style's ring; either of the old
  ones saved takes it (`RETIRED_RINGS` in `Core/DB.lua`). Wider than Blizzard's ring (its band 1.24 times its hole), so
  shrunk to it as the others are. Its texture 1024 × 1024 (`SIZES` in `make_rings.py`; Ikar the same evening: "the
  steampunk minimap look a bit weird, pixelization ?", "especially compared to the cartouche"): at 512 it stood
  magnified on a 4K screen, drawn as large as the map, where a cartouche's art, as wide, covers less of it. Then
  `tools/make_rings.py` makes each a 512 × 512 `Media/MinimapRing<Id>.tga`, its centre in the middle, and
  `Data/MinimapRings.lua` (`inner`, the map's edge, `band`, the band's outer edge, as shares of the half width): drawn
  on a frame of ours over the map (its child, see below), the map's edge 1.5 under its inner edge, Blizzard's ring hidden, the plate's rim
  the one made for Blizzard's ring (Ikar 2026-11-16: "no matter the skin, the outer border must be preserved"; it
  hugged the ring's band before, the ring's art over the plate's border). A ring whose band reaches past Blizzard's
  ring (215 across round a map 198 wide, `MinimapCompassTexture`) is shrunk till it ends there (`Minimap.ArtSize`;
  Ikar's pick, "Blizzard's rim, rings shrunk"): at map 198, eleven of the seventeen, its inner edge then further over
  the map, by up to 9.8 (Astronomy; 7.8 at Ikar's 158.4); round mask
  (`ui-hud-minimap-frame-generic-mask`,
  `GetMinimapShape() == "ROUND"`), takes the map at whatever size Blizzard's Edit Mode gives it (never scales it),
  and hides the redundant top zone/clock bar. **Ours only while the plate takes it** (`Minimap.Owned`: the option on
  and the map in the plate's dome; Ikar 2026-11-15: "when it is not linked, we should not take control over it, and
  revert it to its default form with no change"): placed out of reach in Edit Mode, the map goes back to Blizzard as
  it was, its shape, mask, ring, header and zoom, and so do its widgets, from the bar and the folders too; our
  elements set round it wait hidden, other addons' buttons set round it go back to their addon on the map
  (`Collect.GiveBack`, taken again as they are once the map is ours). Taken again, all is ours again. It changes
  hands as the map is dragged in Edit Mode, not at the drop (Ikar 2026-11-16: "can't it happen during drag?"): out of
  reach it's Blizzard's at once, back in reach ours at once. The zone stands under the map's centre, ours or not. It says where the hub's elements stand round the map
  (`Minimap.Dome`): the plate's dome. Blizzard's widgets (tracking, mail, calendar, compartment, day/night;
  `UI/Hub/Natives.lua`) leave `MinimapCluster` for `UIParent` while placed: the cluster is a `ResizeLayoutFrame`, and
  Edit Mode's size slider calls its `Layout()`, which sized it round them, up the whole screen, the map on its top
  (Ikar 2026-11-14). Not ours (the option off, or out of the plate), everything is given back as Blizzard had it
  (`Frames.Keep`/`GiveBack`: parent, anchors, size, scale, layer, alpha, mouse; the dropdown buttons on the left button
  alone), and the cluster's header goes where Edit Mode's own setting has it (`UpdateSystemSettingHeaderUnderneath`),
  never forced.
- **Unified slot hub (`UI/Hub/`).** `Hub.lua` is the model: every element, where each is saved to stand, the edits
  that move them, where round the map they go. `InfoBar.lua` draws them (the bar, round the map, the folders' lists),
  `Buttons.lua` makes our buttons and the handles, `Menus.lua` the menus and hints, `Drag.lua` the drag and drop;
  `Items.lua` (ours), `Natives.lua` (Blizzard's widgets), `Collect.lua` (other addons' map buttons) and `Folders.lua`
  are the elements' kinds, `Macros.lua`, `Separators.lua` and `Infos/*.lua` (ours beyond the Titan bar's) too,
  `Seeds.lua` the folders KaLi HUD makes (locked but « Add-ons » and « Suite »), `IconPicker.lua` the folders' and macros' icon library, `MacroEditor.lua` the macros'
  editor. Every element — KaLi HUD's items, third-party
  `LibDataBroker` objects, and Blizzard's minimap buttons (`Tracking`, `Mail`, `Calendar`, `AddonCompartmentFrame`,
  `DielFrame`) — shares one slot system: **the bar** (anywhere along it, `free` with `pos`, a fraction of the screen's
  width; or lined up from its **left** or **right** end), **Below minimap** (one block centred under it), **Left dome
  pocket**, **Right dome pocket**, and **Around minimap** (any polar angle), plus **Hidden**. A padlock button at the far
  right of the info bar (`slotsLocked`) unlocks drag-and-drop across all zones. Clicks are the element's own; its
  right-click opens its hub menu (its settings, **Aller à gauche / à droite**, the folder it goes into, ring angle and
  always/hover visibility), but another addon's own while the padlock is shut (below).
- **From its menu an element goes into a folder, nowhere else (Ikar 2026-11-17: "One change also, remove all the sens
  to, except folders. They are noisy options.").** « Emplacement » listed every place, as a "send to": the bar's left,
  where it stands, below the minimap, the bar's right, the dome's two corners, round the minimap, each folder, a new
  folder, « Masqué ». It lists the folders that can hold the element (any but itself and those it holds) and
  « Nouveau dossier… », and for another addon's element its reset; the rest went, their texts with them
  (`SIDE_left` to `SIDE_ring`; `Hub.SIDES`). An element's place on the bar or round the map is the drag's, the padlock
  open; « Aller à gauche / à droite » and, on the ring, « Position sur l'anneau » stay (not asked); « Retirer »
  (« Supprimer » until 2026-11-20) takes it off the HUD, as « Masqué » did.
- **One right-click (Ikar 2026-11-17: Ctrl+right-click was not intuitive, "Let's focus on having a consistent right
  click"; of three ways put to him, "let's go for 3").** The padlock decides, as Edit Mode does, where a click on a
  frame selects it instead of using it (`HubMenus.RightIsHub`). Shut, the HUD used: a right-click is the element's own.
  Ours have none but their hub menu, their own entries first (no quick menu apart, the one menu); Blizzard's widgets
  have none of their own either (the tracking button and the compartment take the left button alone, the calendar's
  right does what its left does, `GameTimeFrameMixin:OnClick`; the mail and the day/night ring take no click), so
  theirs is the hub menu too; another addon's LibDataBroker object or map button keeps its addon's, untouched (no hook
  of ours on its frame; `HubMenus.Theirs`), but one with no click at all, a plain readout: it has no right-click to
  keep, so its hub menu opens, as ours (the review of 2026-11-17, D9: its right-click did nothing while shut, its
  placement out of reach). Open, the HUD arranged: a right-click on any element opens its hub menu,
  another addon's too, nothing of the element's runs (the handles over the widgets and the map buttons take it, so
  their frames stay their addons'). The zone has no hub menu, a separator its own. In a fight the padlock can't open,
  so everything does what its author wrote; one open as a fight starts is shut for it (The padlock in a fight, below).
  Weighed and left: our menu always, theirs one line in it (their
  right-click a click further, their frames' clicks taken for good); theirs always, ours where there's none (another
  addon's element's placement, angle and visibility out of reach).
- **How it stays light.** The hub's list is built once a change (`Hub.Changed`), not for each question (a hover, the
  map's dressing, a redraw). A text, icon or colour that changes (ours every second or so, other addons' through
  `LibDataBroker_AttributeChanged`) draws its own button alone, the bar re-placed only when its width changed
  (`InfoBar.Update`); the dome moving puts back what stands by it without filling anything anew (`InfoBar.Reflow`);
  the map's dressing is done again only when the dome moved or something asked. A full layout, at most once a frame,
  comes from a change of place, an option, the lock, a folder opening; never during a fight (In a fight, below).
  Since the review of 2026-11-17: an open folder's list is laid out once however many of its members changed in the
  frame (D10: five attributes changing laid it out five times, 160 buttons filled against 98 for the whole hub); and
  each element's drawing is guarded (`HubButtons.SafeFill`, D5): one that raises an error is kept once and shows the
  question mark for the session, the rest laid out. It took the bar's whole layout with it (12 buttons of 111 at
  login, forced in a probe; no real object was found that does it).
- **Dragging is seen, and the same for every element.** The element itself follows the pointer (ours: the button;
  Blizzard's: the widget with the handle over it); the drop zones light up in white (the bar but the zone's block
  under the map, which is reserved and takes nothing; its two ends, the ring, the pockets' places) and a marker shows
  where it lands. On the bar it stays where it's dropped, except among the items at an end
  or up to 40 units past them (`LOCK_ZONE`; was 20 from the screen's edge, Ikar: light up sooner), where it joins
  them at its place; the end it would join lights up. The ring's bottom arc, over the zone below the map, takes
  nothing and doesn't light up (Ikar 2026-11-13). Free items and the block below the minimap keep their
  places but never overlap, pushed apart left to right. Off the slots, it goes back; with the info bar off, nothing
  lands at the screen's foot. Unlocked, each Blizzard widget gets
  a handle (`HubButtons.PlaceHandle`): dragged, it takes the widget along; its left click is the widget's, its right one
  the hub menu; a widget hidden for now (no mail) shows its icon on its handle, so it can still be moved.
  An error while something is dragged, at the drag's first frame, each later one or the drop, puts the element back
  and is kept once (`ns.EveryFrame`, `Drag.Cancel`): it came back every frame, unguarded, and left the hub dragging
  until a fight or a reload (the review of 2026-11-17, D7; the rule of what runs every frame, which the drag had
  escaped).
  Locked, the handles go and a right-click on the widget opens its hub menu, alone: the tracking button and the
  addon compartment are DropdownButtons that only take the left button, so they're registered for the right release
  (never the press, which would open their menu); the calendar's own right-click is muted for that click. A handle
  over a DropdownButton toggles its menu itself (`SetMenuOpen`, as Blizzard's `DropdownButtonProxyMixin`), since
  `Click()` doesn't open it.
- **The hints on the tooltips** (`HubMenus.AddHints`): « [right button] réglages et emplacement » where the
  right-click opens the hub menu (a Blizzard widget's, a folder's, a macro's, one of ours whose tooltip says nothing of
  its right-click; another addon's while the padlock is open), never twice (ours with a menu of their own name their
  right-click themselves, with the same words since 2026-11-20: « [right button] réglages et emplacement »), plus « Glisser : déplacer l'élément » while unlocked, under the
  element's own tooltip (the calendar rebuilds its own every frame, so it's added again in its `OnUpdate`), or under
  its name when it has none, its type last. Nothing of ours under another addon's while shut, but its type, and the
  hub menu's hint under a plain readout's, whose right-click opens it.
- **The mouse's buttons as icons (Ikar 2026-11-17: "Replace all click gauche and droit text by the new icon").** In
  every text that names a button, in the four languages, the house editor's own icons stand for « Clic » and
  « Clic droit » (`housing-hotkey-icon-leftclick`, `-rightclick`, Blizzard_HouseEditor's hints, flat grey-brown, the
  button lit in cream: the closest of the game's mouse icons to the plate's bronze, Ikar's pick among the five sets
  Forever has). `Core/Locale.lua`'s `LEFT_CLICK` and `RIGHT_CLICK`, at 16 as Blizzard sets a mouse button in a line
  of text, no colon after: « [left] le chronomètre · Maj+[left] le calendrier · [right] réglages et emplacement ». The hints, the macro's
  right-click label and prompt, the notes' and the padlock's tooltips, the compartment's, the help's line. Words that
  name no button stay words: « Au clic » (a folder opening on a click rather than on hover), the « Clic » sound,
  « Molette » (the set has a wheel icon too, `housing-hotkey-icon-mousewheel`, unused). The login check counts both
  atlases (`Data/Needs.lua`, from the `|A:` in the strings).
- **A double click's icon, stored (Ikar 2026-11-17: "ok, option 4, store it, but we won't use it for now").** No atlas
  of the game's draws one, in Forever or retail. Five were drawn from the house editor's left click: « ×2 » after it,
  « ×2 » by its button (the mouse at three quarters), a second line round the button, two waves off its corner, a 2
  in the corner as WoW's stack counts. Ikar took the two waves: the game's icon moved 5.5 texels down and right, two
  arcs following the mouse's outline in the lit button's cream over its amber glow, as the set's wheel-up arrow.
  `hud/tools/make_double_click.py` draws it from the game's texels into `hud/art/double-click.png` (64x64); nothing
  in the addon uses it yet. Using it means a texture of its own in `Media/`.
- **Each tooltip says what kind of element it is (Ikar 2026-11-17: "It component tooltip, add a type field, can you
  propose names for each ?"; the names proposed then, `HubMenus.TypeOf`).** « Type : … » in grey, the tooltip's last
  line, under the hints (Ikar 2026-11-17: "make type last, currently they are randomly between button"):
  « Information » for ours, the zone too; another addon's object by LibDataBroker's own two kinds, « Lanceur
  d'add-on » (`launcher`) or « Information d'add-on » (`data source`); its map button « Bouton de minicarte
  d'add-on »; Blizzard's widgets « Bouton de la minicarte (Blizzard) »; « Dossier », « Macro », « Note »,
  « Séparateur ». None says « (KaLi HUD) » ("remove the (kali hud) from type"), a folder or macro KaLi HUD brought
  neither. A folder showing its name has no tooltip (Ikar 2026-11-14), so no type there; one showing its icon alone has its
  name, its overflow note for the one that takes what doesn't fit, then its type.
- **The buttons' hints together, left then right (Ikar 2026-11-17: "make sure bouttons always come one after another,
  same order, left then right").** An element's own hints are its tooltip's last lines, each naming its left button
  before its right (« [left] le chronomètre · Maj+[left] le calendrier · [right] réglages et emplacement »); the hub
  menu's right-click hint
  follows them, then the drag's while the padlock is open, then the type. The tests hover our items, another addon's
  launcher, Blizzard's widgets and a folder, padlock shut and open, and check that order.
- **What a click opens takes the tooltip away (Ikar 2026-11-18: "when opening anything, the tooltip should
  disappear").** The game keeps one: Blizzard's calendar button rebuilds its own every frame while it owns it, the
  calendar open or not, and its menus leave it up. Ours goes on any click on an element (`Buttons.lua`'s `onClick`,
  after the element's own or its secure button's): a pane, a list, a note's editor, another addon's window, a macro's
  commands; the pointer coming back on it brings it again. None on a folder's button while its list shows, one opening
  on hover included (its secure handler opened it before our `OnEnter`). The two whose click opens nothing, the
  memory's (freed) and the sound's (muted), have theirs drawn again instead (`keepsTip`), as the padlock's. Every menu
  hides it as it opens (the hub's, the bar's, a progress bar's). Blizzard's widgets on the HUD: the tracking menu, the
  compartment's and the calendar take it away on their left button's press (`Natives.lua`'s `OnMouseDown` hook, once
  hidden the calendar's no longer owns it); the mail and the day/night ring open nothing. Another addon's map button
  taken in: after its own click (a hooked `OnClick`). A widget's handle while unlocked, a window's fold button and the
  editor's icon button the same. Another addon's own tooltip frame (LibQTip's) isn't the game's and stays its own.
- **Every element deletable (Ikar 2026-11-17: "make all components deletable").** A folder, a macro and a separator
  were (a folder asks first, what it holds going with it); every other element's hub menu ends in « Retirer »
  (« Supprimer » until 2026-11-20, which it doesn't): ours, another addon's and Blizzard's aren't the HUD's to destroy,
  so it takes the element off the HUD, the bar, the map and its folder (`Hub.SetShown`), its tooltip saying the bar's
  menu puts it back where it was; one action, undone from the bar's menu. A folder KaLi HUD made too, since 2026-11-20
  (Ikar: "built in folder, when deleted, shoudl only be deselected, otherwise, they are unrecoverable"): « Retirer »
  in its menu in place of « Supprimer le dossier… », what it holds staying in it, its box under « Dossiers » in the
  bar's menu showing it again where it was; the player's own still deleted, asked first. Greyed in a fight with the rest. The zone stays no element (Ikar 2026-11-13): never
  hidden.
- **A press outside shuts the open lists (Ikar 2026-11-17: "when opening a menu, a click outside should close it,
  regardless of the rules").** The game's own menus already shut so; our folders' lists now do too, however each opens
  (`GLOBAL_MOUSE_DOWN`, `Folders`' `pressed`): a press anywhere but on an open list shuts them, one on a list keeping it
  and those it stands in and shutting those opened from it, as a menu's submenus. A press on a folder's button is its
  click's (it opens or shuts it, ONE_OPEN the others); one on our editor, our icon library or one of the game's
  questions is theirs; one while a game's menu is open shuts that menu first (`Menu.GetManager():IsAnyMenuOpen()`), as
  stacked menus do. Not in a fight: no addon may hide a secure list then, and the fight's own rule shuts one once left
  (`folderCombatClose`).
- **The padlock (`InfoBar.UpdateLock`; Ikar 2026-11-17: "make it like a bar cap. And when unlocked, it should be gold
  background, clearly visible. Maybe with a small aura around?"; 2026-11-20: "a separate design for the bar cap. Maybe
  a slightly bigger rectangle with the lock? With textures, something that look nice and catches the eye when
  enabled", then "go for bloc").** A block closing the bar at its right end, picked from sketches drawn over a 1:1 crop
  of the game's bar at 4K (rivets "imply a style, which I want to avoid, as it will be the same in all styles"; the
  padlock kept; nothing arrow-like; "they all look like buttons, not caps"; the bar has no surface of its own: one
  stone, the plate's). Flush with the screen's edge and foot, 1.8 times as wide as the bar is tall, 16 % of the bar
  above its top; the border's colour lit from the top (0.95, 0.62 and 0.36 of it at its top, middle and foot) and
  brushed along (`Media/BandGrain.tga`'s specks run across, as strong as the border's); a dark line along its top and
  down its left side, a lit one inside it, its shadow on the bar beside it (5 wide). The padlock carved in over the
  bar's middle, 55 % of the bar tall: dark, its lower lip lit a pixel under it. The bar's items stop short of it,
  however wide it is at the bar's size. Shut, at rest: the metal; hover brightens it. Open: the whole block the game's
  gold (`NORMAL_FONT_COLOR`, its top nearer white, its foot darker), the open padlock dark on it, nearer white on
  hover, and a soft gold aura round it (`Media/Shadow.tga`'s disc, added, 7 past the block) that fades in once as it
  opens (0.3 s, the game's acknowledgements) and then holds still while it's open, as Edit Mode's selection does: a
  looping glow is what the game's own UI never keeps at rest (its quest items' glow stops after six). It was the
  progress bars' end cap until then (`Border.Attach` with `cap`, the background's colour inside). Not yet seen in
  game.
- **The padlock in a fight (Ikar 2026-11-17, asked whether it opens again after: "Yes, he reopen").** It can't be
  turned during a fight, so one that began with it open kept the HUD being arranged until its end: a macro's own
  right-click ran nothing (`*type2` unset, and no addon may set it then), another addon's right-click opened the hub
  menu, greyed, and never reached its addon (the review of 2026-11-17, D2). As a fight starts
  (`PLAYER_REGEN_DISABLED`, the lockdown not on yet; `InfoBar`'s `fightStarts`) an open padlock is shut: the macros
  armed, the handles gone, the layout done at once, the folders' lists put back in the game's auto-hide where that
  layout placed them (`Folders.FightStarts`: the game drops a list placed anew). Its tooltip then says it opens again
  (`LOCK_REOPENS`), and as the fight ends it does (`InfoBar.Reopens`). One the player had shut stays shut.
  Since 2026-11-20 (Ikar: "make it lock on combat (no unlock after) on disconnect, on connect, on reload"): shut for a
  fight, it stays shut after (the re-opening, its tooltip line and `LOCK_REOPENS` gone), and it is shut at every
  connection and reload (`Core/Main.lua`: `slotsLocked` back to its default as the saved data is opened) and saved
  shut at logout, a disconnection too. Tested by the `padlock` scenario.
- **Places that hold (the review of 2026-11-17, D4).** Ikar's rule, of the mail's place: nothing moves on a game event
  outside Edit Mode. A text that gained or lost a letter moved everything laid out after it on its side: the frame
  rate crossing 100 shifted the whole right side each time, as would any other addon's object whose text varies in
  length. (The game's font has digits of one width, 6.40 at size 10, measured: only the number of letters matters, so
  the clock and the coordinates never did.) Each of ours and each other addon's object on the bar keeps a place as
  wide as the widest it has needed (`InfoBar`'s `places`, `hold`), its text at the place's left: a text that grows
  widens it once, one that shrinks leaves it, with no layout at all. Forgotten when the player arranges the bar
  himself (`InfoBar.Forget`: the padlock turned, a setting changed, a box or a choice of an element's menu, a move, a
  hide, a creation or a deletion through `History.Do`, an undo, a redo): each then takes its own width again. In a
  fight a text that grows within its place needs nothing done. The zone keeps to its own width: it stands centred
  under the map, and a place wider than its name would leave that name to one side of the centre; so the coordinates
  and the clock still move with a zone's name, as they always did, which the same rule would stop: to rule, with
  the name centred in a place that holds. Not done either, for Ikar to rule: a limit on another addon's long text
  (the review's P1, its second half).
- **What doesn't fit on the bar (the review of 2026-11-17, D3; Ikar 2026-11-17: "You mean in the bottom bar ? Maybe a
  special folder ?").** The bar's left items are laid out from its left end and its right ones from its right end,
  and nothing saw to their meeting: more than the bar is wide was drawn one over another and off the screen. Measured
  with the game's font, French, size 10, a first run needs about 950 units; a 16:9 screen at the game's default UI
  scale has 1365 (Ikar's 2100), so it fits at 10, barely at 14 and not from 15, and five or six other addons' data
  sources use up what's spare at 10. Now (`InfoBar`'s `fit`, before the bar is placed), while its items run over one
  another (`excess`: the left row, what stands between, the right row; what came down from the pockets not counted,
  which goes first as before), the innermost item of the longer end leaves the bar for this layout: never a folder,
  nor the zone, nor what's being dragged; after the ends, the items set free, then the block's below the map. What
  leaves goes into the list of **the folder for it**: the one a folder's menu says (« Ce qui ne tient pas sur la barre
  arrive ici », its `overflow`, one at the most, as « Les nouveaux add-ons arrivent ici »), « Suite » by default, made
  by the layout the first time something doesn't fit (`Seeds.Overflow`, `db.seeds.overflow`: deleted, it isn't made
  again), at the bar's right end by the padlock (order 0, before every item there, none renumbered), its chevron
  alone on its button, its list of icons with their text running down, one of the folders KaLi HUD brings, not
  locked. In its list an element works as ever, a macro, another addon's button, one of Blizzard's widgets, in the
  order they read on the bar (the left side's in its order, then the right side's from its inner end). Its place is
  still the bar's, saved and shown so in its menu, and it's back on the bar at the first layout with room.
  « Suite »'s button shows on the bar only while it holds something, or while the padlock is open, to be arranged
  (by its role, so its box unticked too: ticking the box of another folder doesn't bring an empty « Suite » up on the
  bar); its tooltip says what it's for (`FOLDER_OVERFLOW_TIP`). A folder of the player's told to take what doesn't
  fit is a folder as any other, on the bar where he put it, holding nothing too: one that left the bar as its last
  element was dragged out would look deleted (« Suite » renamed is his, and stays so too). The folder he had told to deleted, « Suite » takes it again while there is one
  (`Folders.Delete`): a deletion that says nothing of it would else leave what doesn't fit with nowhere to show. With
  no such folder (its box unticked with no other ticked, hidden, « Suite » deleted), what doesn't fit is drawn nowhere
  until there's room, a widget of Blizzard's too, no handle left where it stood (`InfoBar.Where`, which `Natives`
  reads). A place growing past what the bar has left has it laid out whole (`flush`). Left as they are: a bar that
  folders alone overfill (they stay, and lie over one another), and the folder's name, « Suite » ("More", « Mehr »,
  « Más »), proposed, Ikar's to change as the types' were.
- **Go left / go right (`Hub.Step`).** Two rows: the bar (left, then the free items and the block below the
  minimap by where they stand, right) and the dome (left pocket, the ring by x, right pocket). The element goes past its
  neighbour on that side, crossing into the next part of its row; on the ring, one button past it; in a pocket, to its
  next place that way, free or not. **A pocket's places stand as its triangle** (`Geometry.PocketSpots`; Ikar
  2026-11-16: "you removed the triangle, keep it. I just wanted equal spacing, but on the triangle"): rows along the
  floor, columns up the dome's side, each row one shorter, so three are one in the corner, one above it, one beside it
  towards the map. Evenly spaced: the same gap between two icons as between an icon and the pocket's edges (the dome's
  side and the floor 2 in, the ring 2 onto it, those 2 counted in), the widest the pocket lets them have, so they spread
  as far as it goes (Ikar 2026-11-15: "they should take the whole triangle spread out whenever possible") without
  pressing into its corners (2026-11-16: "no need to put them in the corners"); never under the map's middle half, the
  zone's. Six (a row and a column more) where they still stand half an icon apart (Ikar 2026-11-16: "when we can
  afford, maybe add more than 3 slots"); three as soon as they stand apart at all; else two, else one. (An arc of equal
  shares round the ring, tried that day, lost the triangle.) A status bar under the pocket is its floor there
  (`Hub.PocketSpots` reads the plate's status slots, its cap included): the triangle on the info bar beside the bar's
  end or on the bar, whichever spreads it more. **Any place can be chosen** (Ikar 2026-11-16: "you cannot choose freely
  one of the 3 spots, you have to fill them one by one"): an element keeps the place it was dropped on (its `slot`),
  free places before it or not; dropped on a taken one, the two change places (the one there goes to the first free
  place when the dragged one came from elsewhere); one with no place saved, or whose place the pocket lacks at this
  size, takes the first free (`Hub.PlaceOf`). Each place is a drop zone; unlocked, the free ones are marked on the
  plate. **What doesn't fit goes on the bar** (Ikar 2026-11-16: "they should be put into the bottom bar, or if no space, removed altogether";
  `Hub.Spills`, `InfoBar`'s `collect`): beside the block below the map on its pocket's side, the innermost nearest it,
  in its bar form; while the bar's middle can't hold them all, the outermost go first; with the bar off, nowhere. It
  keeps its pocket as its place, so it goes back up when the size leaves room again (`InfoBar.PocketsHold`, after each
  plate drawing). Each pocket its own places, as a status bar may stand under one alone. A
  place is the icon size plus 2. Every icon is drawn at the icon size, its art and not its empty margin (Ikar
  2026-11-14, "all the icons"): our atlases cropped to their drawn part (`UI/Hub/Buttons.lua` ART, measured in Forever's
  art), shape kept, the longer side at the size; Blizzard's map widgets scaled so their art's longer side is the size
  (`UI/Hub/Natives.lua` DRAWN: the framed buttons 22, the compartment 18.5, the envelope 28, the day/night ring 38.5,
  each at Blizzard's own frame size, on the bar as round the map; the
  ring's own `minimapDielScale` now a % of it, 100 by default); the handles' icons and the padlock too. Ours
  and addons' show their icon on nothing (Blizzard's dark round button behind them, 23 across
  whatever the icon size, is gone: Ikar 2026-11-14, "the dark behind the icons"). Ikar 2026-11-14: icons closer to
  the circle, "ok if it encroaches a bit", larger icons accepted, kept in triangles (a fan along the ring was
  refused); three places from a map at 70 % with icons at 14, 79 % at 16, 87 % at 18. The pocket marks
  (`pocketMarks`) are drawn on free places only, and only while the slots are unlocked (Ikar 2026-11-14).
- **Info bar sizes.** One size (`infoSize`, Ikar 2026-11-15: "unify hauteur, taille du texte and tailles des icônes
  into taille"), its text's in the game's small font: the bar 1.8 times as tall and the icons 1.4 times as large,
  rounded (`Hub.BarHeight`, `Hub.IconSize`), as they stood at 10, the default (18 and 14); 6 to 20, the smallest bar 11
  tall. The spacing (`infoSpacing`, 10) is the one at size 10 and follows the size (`Hub.Spacing`). A saved text size
  from before becomes the size; the height and icon size go. Its Edit Mode section: the size, the spacing, the lock,
  the folders' sound. The plaque option is gone (2026-11-13: it drew only
  dividers; the map's items never get a border, and the cartouche waits for real art).
- **Blizzard's widgets show always by default** (tracking, mail, calendar, compartment, day/night; Ikar 2026-11-13:
  the calendar on hover looked gone once locked); hover stays a choice in each one's hub menu.
- **Folders (`UI/Hub/Folders.lua`; Ikar 2026-11-14, in place of MinimapButtonButton, whose licence reserves all rights:
  our own code).** A folder is an element of the hub like any other, wherever it's put, showing its icon and its name,
  its icon alone (Ikar 2026-11-15) or its name alone (« Affichage » under « Renommer… » in its menu, `iconOnly` or
  `nameOnly`, as a macro's; Ikar 2026-11-16: "should be able to show name, icon, or both"; in a list with text its
  name by its icon unless its name alone); a click opens its list next to it, in the thin border and the plate's
  background, darkened as the info bar carved into the plate is, carved or not (`Plate.CHANNEL`; Ikar 2026-11-16: "the
  menu background should match the darkened version of the bottom bar, even if she is not darkened"). **One folder
  open at a time (Ikar 2026-11-16: "only one folder open at a time, opening another close the previous"):** opening
  one, by a click, the pointer or our code, shuts every other but those it stands in (the snippets, through a
  registry, a secure frame holding every list's ref; saved data with several open keeps the innermost; each climb
  out from a folder at most as many steps as there are folders, so that a folder in itself, which nothing makes,
  can't hold the game in a snippet). **In a
  fight, every folder shuts once the pointer has left it** (« En combat, les dossiers se referment quand on les
  quitte », the info bar's section of the Edit Mode panel, on by default; Ikar 2026-11-16: "always auto close in
  combat. make it an option, on by default"): one opening on a click is registered with the game's auto-hide when the
  snippet sees `PlayerInCombat()`, one open as the fight starts during `PLAYER_REGEN_DISABLED` (shut once the pointer
  has been on it and left it), back to staying open as the fight ends. **It opens in combat too (Ikar 2026-11-16: "can a folder opening be secure? ... if running a
  macro is allowed, I don't see why opening a folder would not"; a folder locked in combat with a tooltip was what he
  wanted to avoid).** Its button is Blizzard's `SecureHandlerClickTemplate` and `SecureHandlerEnterLeaveTemplate`, its
  list a `SecureHandlerShowHideTemplate` (`Blizzard_RestrictedAddOnEnvironment`): their snippets, which the game runs on
  the player's click or pointer, show and hide the list; one closing on leaving or opening on hover is registered with
  the game's own auto-hide (`RegisterAutoHide(0.4)`, the button added with `AddToAutoHide`), which replaced our timer;
  the list tells our code it opened or shut through `CallMethod` (its sound, the button pressed in, `f.opened`). The
  snippets read nothing of the game: presentation on the player's input, as Blizzard's own templates intend, no
  automation. A frame can't become secure later, so every folder's button is (`HubButtons.Make`, known by its id). Open, it's pressed in, the usual toggle (Ikar 2026-11-14, not gold): a dark well round its icon
  and name, lit from the top left (upper and left walls in shadow, lower and right lips lit),
  the icon a unit down and right. It has no tooltip (Ikar 2026-11-14); one showing its icon alone, its name.
  Anything goes in (ours, other addons', Blizzard's widgets, other addons' map buttons, other folders). As many as wanted: made from the bar's menu or an element's placement (« Nouveau dossier… », named in a
  popup), each with its settings in its menu (`db.folders[id]`): icons only, in a grid of N a line (`perLine`,
  1–25, « Éléments par ligne », a slider: Ikar 2026-11-20, "Ça doit être un slider avec la limite max à 25"; the
  game's own with its steppers in a frame of Blizzard's menu, `Menus.Slider`), or icons and their text, N to a line too, the next beside it (Ikar 2026-11-16: "let's
  add column even for text, same as icon only"; a column when the list runs down, a row when across); horizontal or
  vertical; opening up or down, to the left or right
  (`dir`, its side flush with the button's, kept on the screen); icons from the button, the first next to it; texts
  read as a page, from the top left whichever way the list opens, as Blizzard's menus that open upwards still read
  downwards (Ikar 2026-11-20, the attributes' list opening up from the bar: "somethings off", each title under its
  group; then the emotes', opening to the left: "emote ordered weirdly", its columns from the right); on click, on click closing when the pointer has
  left it 0.4 s, or on hover; rename, delete. **Deleted, with all it holds (Ikar 2026-11-16: "prompt the user if he
  is sure, as the content will be deleted, not displaced"):** asked first, the question saying so (« Supprimer le
  dossier « X » et tout ce qu'il contient ? Ses macros, séparateurs et dossiers sont supprimés, les autres éléments
  masqués. »; an empty one, the short question); the folders, macros and separators in it deleted, however deep;
  what can't be (ours, other addons', Blizzard's widgets, map buttons) hidden, out of any folder, shown again from the
  bar's menu; undone from the bar's menu. Items in a folder are
  `side = "folder"` with `folder = id`; dropped on a folder's icon they go last, in an open list before or after the
  nearest, a rule across the line between the two marking where while dragged (a list running down, a horizontal
  one; across, an upright one; Ikar 2026-11-16: "highlight the line between two element, the current circle is
  unclear"), the ring left for a folder's icon and an empty list. Anywhere along the line, not only over a name; while dragging, no button lights up under the pointer (`Buttons.Highlights`): in a list a button is as wide as its text, so its gold hover light followed the names and read as the drop's place (Ikar 2026-11-19: "the position hight only when you hover on top of a texte, not the whole line"). In a list of several lines, the drop goes by the line the pointer is in (as thick as the line), then along it, each member as long as it takes: by a member's middle, the next column's won while the pointer was still over a long name's end (Ikar 2026-11-20: "it switch to the right column too early, when the cursor is still on the left"). At the first run, or the first with saved data from before folders, one comes made, « Add-ons », at the
  bar's right end, the default one (« Les nouveaux add-ons arrivent ici »): other addons' launchers and map buttons
  land in it, and the launchers saved on the bar are moved in. Their data sources landed on the bar (Ikar
  2026-11-14) until 2026-11-17, when he agreed that nothing lands on the bar unasked (The second round's rulings,
  below): a new one lands in the folder too.
  - **Folders in folders (Ikar 2026-11-16: "I think we will also need folder in folders").** A folder goes into any
    other, however deep, never into itself nor into one it holds (its placement menu doesn't offer them, a drop
    there finds nothing, `Folders.CanHold`; saved data holding a ring of them puts the first by its id back where it
    goes by default). It opens as a menu's submenu: its list beside the list it stands in when that one runs down,
    flush with its button's foot (opening up) or head; beyond it when it runs across, flush with its button's side;
    which way, unset, its host's. One folder open at a time, but those it stands in (above), each shut
    with the list it stands in, in a fight too: the snippets do it, from frame refs set out of combat (a list's
    folders as `sub1`…, a folder's button's list as `up`, a list's button as `owner`). A list closing on leaving is
    registered with the game's auto-hide again as one opens from it (`RegisterAutoHide` takes the rects at once), the
    lists opened inward from it down to that one added, so the pointer on them keeps it open. Laid out a folder before
    those it holds (`Folders.Ordered`), each list a level above the one it stands in. Dropped on a folder's icon,
    wherever it shows, an element goes into it before any open list's places count. Deleted, the folders it holds go
    with it, theirs too (above).
  - **Separators (`UI/Hub/Separators.lua`; Ikar 2026-11-16: "add a separator to the menu, draggable, deletable, added
    by folder option").** « Ajouter un séparateur » in a folder's menu puts one last in it (`db.separators[id]`, its
    place an item's); dragged like any member, into a folder only; its right-click deletes it (its own menu, the padlock shut or open); gone with
    its folder. A separator is a rule across its line, between its neighbours, one pixel thick, the game's menus'
    shade, in a gap of 9 (Ikar: "separators, I thought about horizontal, not vertical, vertical there is no need, max
    number should handle them, and vice versa for horizontal folders"): down a list, a horizontal one in its column;
    across, an upright one in its row; the lines made by « Éléments par ligne » alone, a separator not counted, one
    after a full line at its end. Not in the bar's menu.
  - **A list's sections and values (Ikar 2026-11-20, the sketch of the attributes: "C'est très bien"; "whatever we do
    there, I want it to be recreatable by the user").** All settings any folder or separator has, the player's own as
    those KaLi HUD makes. A separator's menu: « Nommer… » (blank: none), « Commence une colonne » (« une ligne » in a
    list running across), « Supprimer » (`db.separators[id]`: true, or `{ name, line }`). Named, in a list of icons
    with their text running down, it is a section's title: its name in gold over a gold rule, as tall as a member,
    going with what follows it (to the next column after a full one); elsewhere a rule, its name in its tooltip. One
    that starts a line begins the next column (row), whatever the count. « Affichage de la liste » (« Affichage »
    alone until 2026-11-20, as the folder's button's look above it: "you also have 2 affichage in folder option, and
    the second has none for name only") offers icons alone, icons and their text, or their text alone (`style`
    "names": no icon by an item of ours or a launcher that has a text; Blizzard's widgets and other addons' map
    buttons, frames of their own, keep theirs), and has two boxes for a list with
    text: « Valeurs alignées à droite » (`align`: a data source's name, its label, on the left, its value, its text
    less the label it starts with or another addon's text whole, on the column's right) and « Valeurs vides en gris »
    (`dim`: 0, 0 %, 0,0 %, 0 (0), a dash, « Aucun » in grey, name and value; « Révéré 0 % » says something).
  - **The bundled lists with them (Ikar 2026-11-20: "fais un tour sur tous nos menus et vois comment les améliorer
    avec ce système").** The attributes under the sheet's own six titles (Général, Caractéristiques principales, Armes,
    Modificateurs, Défense, Résistances), a column each for what the character is, how it attacks (the weapons and
    the modifiers, fourteen: sixteen to a column), how it stands; values aligned, those that say nothing grey. The
    emotes under « Emote » and « Emote Voix », the voices from a column of their own; the group's markers under
    « Marqueurs de terrain » from a column of their own, none cut in two. Values aligned in the statistics (grey too),
    the reputations, the weapon skills, the professions, the reagents (a reagent's red 0 a warning, not greyed).
    Left as they were, too short for titles to help: « Infos », the session, the guild, the group's first two.
  - **A column's texts aligned.** In a list running down, a column holding icons starts the text of an item of ours
    without one (an attribute, a weapon skill) past an icon's room, where its neighbours' start, as other addons'
    labels already did.
  - **Made for the bar's items (`UI/Hub/Seeds.lua`), locked (below).** Weapon skills, professions, attributes,
    reagents, statistics, guild, group and raid, session, and « Infos » for the rest, each with its role
    (`db.folders[id].role`; an item made for it, `obj.home`, stands there by default), its icon alone, its list of icons with their text running down, nine to a column (the attributes'
    longest kind, the group's eight markers and their clearing), opening up and right, a separator between its
    kinds. « Emote » eleven to a column, each kind of emote in two. At the inner end of the bar's left side: the map stands near the screen's right edge, its side
    of the bar short (nine more buttons there pushed the zone off the map's centre), and nothing already on the bar
    moves.
  - **Locked folders (Ikar 2026-11-23, seeing one more one-time step for each change to what a folder holds: "Maybe
    we could avoid that nightmare by making them read only ? No edit, no reset, user can delete them whole (and bring
    back) and if they drag and drop, it create a copy (so no "bring back") option either"; then "let's call them
    "locked" folder. In the future, extensions may create their own. The type shoudl be also "locked folder"").** The
    folders made for the bar's items and « Emote » (a spec saying `locked`, as an extension's could) are the code's.
    At each login and after a set is applied (`Seeds.Sync`), each is made as the code makes it: its name in the game's
    language, its icon and settings, its contents in their order (ours; the macros made for it, `db.macros[id].seed`,
    `"<role>:<key>"`, restored where they differ; its separators and their titles), each on its own, whole or not at
    all; one not there is made at its place, the same step for a first install and for one a later build adds. So a
    later build's contents reach a game saved before with no step of their own. What the code no longer puts in one
    goes: its separators and macros deleted, an item where it goes with no place saved. Nothing goes into one
    (`Folders.CanHold`, a drop on its button too). Its menu and its elements' say « Glisser un élément en fait une
    copie », greyed, its tooltip why (`FOLDER_LOCKED_TIP`); the folder's holds « Retirer » besides, which takes it off
    the HUD whole, its box under « Dossiers » in the bar's menu bringing it back; a macro's « Copier ». Its type reads
    « Dossier verrouillé ». Never deleted: in a folder of the player's that is, it's taken off the HUD, as ours are.
    Dragged out, an element stays in it and a copy lands where it's dropped: an item's a copy element (`db.copies[id]
    = { of = name }`, `KaLiHUD_Copy<n>`, the item's own object, so its value, tooltip and clicks; « Copie », deleted
    from its own menu, its item kept), a macro's or a separator's the player's own, no seed. « Add-ons » and « Suite »,
    made by KaLi HUD too, aren't locked: they hold what lands in them, other addons' buttons among it, which can't be
    copied; their names follow the game's language at each login, and their menus take them off the HUD as the locked
    ones' do. Renamed, a folder has no role and is the player's. One of ours outside a locked folder is reset by
    « Réinitialiser » in its hub menu, asked first (its own options, the clock's, the bags' and the gold's, at their
    defaults; where it goes by default), in place of the placement's reset, which the others keep.
  - **Undo and redo (`UI/Hub/History.lua`; Ikar 2026-11-16: "add an undo/redo stack, up to 10 actions. movement,
    deletion, creation").** The last 10 actions on the hub's elements: a move (a drag, going left or right, the
    placement, the angle, the placement's reset, hiding or showing from the bar's menu), a making (a folder, a macro, a
    note, a separator, a paste, a copy out of a locked folder), a deletion, a reset, a folder's rename, a macro saved
    from its editor. « Annuler :
    déplacer « Sacs » » and « Rétablir : … » at the top of the bar's menu, greyed with none and in a fight; two keys to
    bind in the game's key bindings, under KaLi HUD (`Bindings.xml`, unbound). Each keeps what it changed in the saved
    data (the options, the items' places, the folders, the macros, the separators, the copies; a folder's being open left
    out),
    field by field: undone, those fields go back, only those, so what changed meanwhile apart from it stays; done
    again, as they were just before the undo. A new action forgets what was undone. For the session; not in a fight,
    nor while something is dragged.
- **Macros (`UI/Hub/Macros.lua`, `UI/Hub/MacroEditor.lua`; Ikar 2026-11-16: "allowing the usage of macros in the
  components. They could either reuse an existing macro, or write their own"; "I want both").** An element of the hub
  like any other, in a folder, on the bar or round the map, its name by its icon, its icon alone or its name alone
  (« Affichage » in its menu, as a folder's; Ikar 2026-11-16: "macro should display their name when they have one,
  and as any other, should be able to show name, icon, or both"): a left click runs it, its own commands (`macrotext`) or one
  of the game's macros by name (`macro`, so the game's macro window still edits it), through Blizzard's
  `SecureActionButtonTemplate`, as an action button runs a macro: in combat too, on the player's click only. Acting on
  the release, as the hub's clicks are registered (`useOnKeyDown` false: an addon's secure button is told nothing of
  the press, so it would follow `ActionButtonUseKeyDown` and act on the press alone); the left button only
  (`*type1`), the right click its menus'. Saved account-wide (`db.macros[id]`: name, icon of the library, commands up to
  the game's 255 letters, or a game macro's name). Its icon the one picked, else the game's macro's own, else the text
  glyph; a game's macro gone (`UPDATE_MACROS`): it runs nothing, the question mark on it, its tooltip saying so. Its
  tooltip its name, then its commands (8 lines), grey. Its right-click menu: « Modifier… » (open in combat too, to read
  or prepare), « Copier » (the game's « Copier »), « Coller « … » » beside it, « Supprimer la macro… »; a folder's menu
  and the bar's add « Nouvelle macro… » and « Coller « … » » there (copied for the session; pasted, a new macro with
  the same fields). Dragged, it runs nothing until the drop's click has passed. « Changer l'icône… » in its menu as in
  a folder's (Ikar 2026-11-16: "the icon picker for a macro does not open... It should use the same [as the] folder
  already had"): the same library next to its button, worn at once.
  - **The editor (Ikar: "with edit, copy, paste capabilities").** Plain as the icon picker: its name, its icon (the
    library beside it), « Exécute » with its own commands or the account's and this character's macros (the game's
    « Macros générales » and « Macros |2 <nom> » titles; no note among them), then a section for each button (Ikar
    2026-11-20, of the sketch: "Macro parfaite, implémente"), a faint ground and gold edge: the button's icon and
    « Commandes » at its head, the count of its letters on its right (« 3/255 »), its short description (one line,
    « Description courte, dans l'infobulle » in grey while empty, Blizzard's box with instructions), its commands (255
    letters); a game's macro's commands shown to read, the game's macro window editing them, said under them. The
    right-click's head has an info icon whose tooltip says when they run (the padlock shut). Then « Infobulle », « Vide
    : ses commandes » in grey in it while empty. Tab goes as they stand. Text copies and pastes in its boxes as in any of the game's (Ctrl+C, Ctrl+V). « Sauver » keeps it,
    greyed during a fight with its tooltip; Escape, « Annuler » or its X shut it unsaved. It opens next to the macro's
    button as a folder's list does (Ikar 2026-11-17: "I want the menu to open as a folder popup, near the button";
    `Folders.Place`, the lists' own rule): from a folder's open list, beside it the way that folder opens, level with
    the button; from the bar, towards the screen's middle, flush with the button's side; from a shut list, where that
    list would open; with no button shown, mid-screen. Held by its corner by the button, a note's shorter editor
    shrinks away from it. A new one's opens on the next frame, once the bar has placed its button.
  - **To try (Ikar 2026-11-16: "as a test, a folder, with emote (bulle icon) and vocal emote (lien de discussion).
    Use bulle for the folder itself. Call it emote"; then "I asked for a list of all the emotes, not just 2, they just
    need to be split into 2 categories, with different icons").** Locked (above): the folder « Emote » with the speech bubble, second from the bar's right end, its list
    running down: every emote of the chat menu (`EmoteList`, 22), the bubble on them, a separator, then every voice
    emote (`TextEmoteSpeechList`, 22), the chat link on them; each named and run by its slash command in the player's
    language (`EMOTEn_CMD1` of its token, as the chat menu labels them, in its order). The voice emote of the player's
    faction is left out: the macros are the account's.
  - **Notes (Ikar 2026-11-16: "unsure about note, may need an editor?").** A macro that runs nothing, made by
    « Nouvelle note… » in a folder's or the bar's menu; its text up to 1000 letters in the same editor, read in its
    tooltip (30 lines, wrapped), the book on it by default (`note = true`). Its left click opens its editor, a second
    shuts it unsaved, as a folder's click its list (Ikar 2026-11-17: "make the note open with left click"; the object's
    `OnClick`, which `Buttons.lua` calls after the secure button's own, `*type1` staying unset); its tooltip says so
    under its text (« [left] l'ouvrir »), an empty one's « Note vide : [left] pour l'écrire. ». No « Exécute » in a
    note's editor ("Remove the execute from note"): its text stands in that row's place, the editor shorter by it. A
    note stays a note and a macro a macro: « Rien : une note » went from a macro's « Exécute » with it, as a macro
    turned note could never have come back.
  - **Its own right-click and its own tooltip (Ikar 2026-11-17: "Add the right click, and the tooptip").** Two more
    boxes in the editor, neither for a note (its text is its tooltip): the right button's section, 255 letters, and
    « Infobulle », 1000 (`db.macros[id].right`, `.tip`,
    checked at load as its commands and a note's text are). The right-click's commands run on the same secure button
    by the right button (`*type2`, `macrotext2`: the game's own suffix for it), in combat too, on the player's click,
    while the padlock is shut; open, the HUD arranged, its right-click is the hub menu's as every element's, so they
    run nothing then (`Macros.ArmAll` as the padlock turns; `HubMenus.RightIsHub` counts a macro's own right-click as
    another addon's is counted). With one of the game's macros on its left button, the right one never runs it: the
    secure button reads `macro` before `macrotext` (`SECURE_ACTIONS.macro`), so `macro2` is set to `ATTRIBUTE_NOOP`,
    Blizzard's own way to rule one out. Its tooltip, when written, shows in place of its commands; without one, its
    commands, then its right-click's under the right button's icon. Copied and pasted with the rest. Weighed and left for now (Ikar 2026-11-17, "Do you think it is worth it?"):
    a value of its own on the bar written in a small language of templates over the game's values (colours, icons,
    conditions, translations by the game's own words); a value picked from a list, if players ask.
  - **Each button described, its right-click's letters counted (Ikar 2026-11-18: "Add Description to the macro right
    and left button, on top of infobulle. Single line enty, short. Add the character left for the secondary button
    click").** Under the right-click's box, the game's count of its letters, as under the commands' (« 4/255
    caractères utilisés », `MACROFRAME_CHAR_LIMIT`). Then « Description de chaque bouton : » over two single lines,
    each with its button's icon in the icon's column, its box in the name's: 40 letters (`Macros.DESC_LETTERS`;
    `db.macros[id].leftDesc`, `.rightDesc`, at most `DB.DESC_BYTES`, one line, checked at load), its blanks squeezed
    and trimmed as saved; then « Infobulle ». Neither for a note. In the tooltip, one line under what it says, as our
    items' hints: « [left] Danser · [right] S'asseoir »; the right's only while the right-click runs its own commands
    (the padlock shut: open, its right-click is the hub menu's, whose hint follows). Copied and pasted with the rest. Tab runs from the right-click's box through both lines to the tooltip's.
  - **Next (Ikar: "will need soon"): action-button behaviour.** Not built: the macro's spell's icon and tooltip
    (`#showtooltip`), its cooldown sweep, charges and count, greyed when unusable or out of range, as Blizzard's action
    buttons draw them.
- **In a fight (Ikar 2026-11-16: "grey out any menu item that becomes unusable, in case the user tries to show, hide
  or move anything during combat, with a clear tooltip. This seems like an acceptable tradeoff").** The game forbids
  any addon to move, show, hide or size a secure button during a fight, nor what holds it or what it's anchored to (the
  bar, a folder's list; anchoring one to a neighbour on the bar would have frozen that neighbour). So the hub holds
  still: no layout until the fight is over (`InfoBar.Refresh` waits, one when it ends); a text that grows runs into
  its margin, drawn in place; what waited is drawn as the fight starts (`PLAYER_REGEN_DISABLED`, the last moment the
  game allows it), where a drag also goes back and the secure elements shown on hover round the map show for the
  fight. Greyed in every hub menu, polled so one open as the fight starts greys too, each with a tooltip (the game's
  « Impossible de faire ceci tout en combattant. » in red, then why): going left or right, the placement, the angle,
  the visibility, leaving a button to its addon, the lock, Edit Mode, a new folder or macro, pasting, a folder's
  settings, deleting, resetting, undoing and redoing, showing or hiding an element. The padlock and a drag are refused with the game's error line;
  the tooltips' drag hint says « Glisser : après le combat ». Opening and shutting folders, running macros, the
  elements' own clicks and menus, editing a macro's text stay. A `/reload` in a fight draws the hub once it's over.
- **A folder's icon (`UI/Hub/IconPicker.lua`, `Data/Icons.lua`; Ikar 2026-11-15: "an icon library to select the folder
  icon", the spells' too big).** The game's only library, the macros' and gear sets' (`IconSelectorPopupFrameTemplate`
  over `GetMacroIcons`), holds the spells' and items' painted squares; ours is 246 of Blizzard's atlases drawn to be
  read small, picked by hand (132 until Ikar 2026-11-16: "can you add more?"; each looked at first on a sheet of the
  game's art, the race portraits left out as mud at that size, the gem sockets as mere corners, anything drawn under
  about 16 texels as blurred). An atlas names its element, so the game picks its finest resolution (-2x) itself.
  `hud/tools/make_icons.py` measures each one's drawn part (texels over 40/255 alpha, as `HubButtons`' `ART`) so every
  icon comes out at the icon size, and writes the list; `--sheet <page.html>` draws it by category, each name on hover.
  « Changer l'icône… » in the folder's menu opens the picker next to its button (towards the screen's middle, flush with
  it, the folder's list shut); a macro's too; from the macro editor, beside the editor, its tops level with it. It
  stands over everything (`FULLSCREEN_DIALOG`): opened from the editor, which rises over its own layer when clicked, it
  was under it (Ikar: "does not open"). titled with its name and the game's « Sélectionnez une icône : »; a click changes the
  folder's icon at once and shuts the picker (Ikar 2026-11-17: "when an icon is selected, close the icon page"; it
  stayed open before, to try another), Escape or its X shuts it unchanged. Saved as `db.folders[id].icon`, the folders'
  own unsaved; a name not in the library is dropped at load, so no icon of the 132 left the library.
  - **By category (Ikar 2026-11-16: "can you classify them?").** Fourteen: Outils (the game's white glyphs, the folder
    first, drawn in the folders' bronze), Marqueurs (raid markers, pings, the map pin), Signes, Symboles, Menus du jeu
    (the micro menu's, in its order), En ville (the minimap's tracking icons, home), Carte et voyage, Aventure,
    Quêtes, Métiers, Classes (Forever's nine), Combat et factions, Richesses et sacs (coins, the bags' filters, the
    loot rolls), Compagnie et voix (`ns.ICON_GROUPS`, named by `ICON_GROUP_<id>`). **All at a glance, in one panel
    (Ikar 2026-11-16, having seen a list of categories with one shown at a time: "can we see them all in one panel?
    Even big? At a glance? By category without switching?")**: each category's name over its icons (8 a line, 22
    units in cells of 28, larger than the 20 in 26 before), the categories in the library's order down columns, split
    so the tallest column is as short as can be; three columns, one more while the picker would take more than 85 % of
    the screen's height (about 740 by 560 units where it was tried). One tall column was refused first, as past 900
    units; columns hold it.
  - **Plain (Ikar 2026-11-16: "the yellow is terribly yellow. Use a more tuned down color"; "make the background
    neutral, the whole window is not supposed to be fancy, simple, functional and clear").** No HUD border nor
    material: a dark grey ground (0.07, 95 %) in a grey line one pixel wide (`PixelUtil`), the game's close button. The
    title and the categories' names in a muted bronze (0.8, 0.7, 0.52), not the game's gold; a cell under the pointer
    lightened (white, 10 %), the icon the folder wears on a lighter square (white, 18 %), no longer pressed into a
    bronze-lipped well. The white glyphs keep the folders' bronze, as on the folder's button.
  - **Each named on hover (Ikar 2026-11-16).** The game's own word when it has one (`game`: a GlobalStrings name, so
    in the player's language: the tracking menu's names, the raid markers', the pings', the bags' filters', the
    professions', the micro menu's, the friends list's; a class's from `LOCALIZED_CLASS_NAMES_MALE`), else ours,
    French or English (`fr`, `en`, the game's words of this build when it has them, the other languages getting
    English as the addon's own strings). White, as a tooltip's title.
  - **What the game no longer has (Ikar 2026-11-16: "it should handle gracefully missing icons in case Blizzard
    changes them... a default icon, like a question mark").** In the picker, an icon the game lacks takes no place and
    a category left with none no heading. Wherever KaLi HUD draws an atlas of its own (a folder's icon, our items', the
    handle over a hidden widget), one the game lacks shows Blizzard's own question mark, `QUESTION_MARK_ICON` (as the
    encounter journal and the auras do; file 134400 without the constant), at the icon size, untinted
    (`HubButtons.FitIcon`); the folder keeps its pick, so it comes back if the game does. The self-check's « icons »
    says which atlas or name went (at login, once a build, and in the report): the library is then made again.
- **Other addons' minimap buttons (`UI/Hub/Collect.lua`).** LibDBIcon's are put away (parented to a hidden frame): their
  LDB object is already an element; so is a button whose addon has an LDB object of the same name (KaLi Recipe's
  `KaLiRecipeMinimapButton` beside « KaLi Recipe », Ikar 2026-11-14). Other named, button-sized, mouse-enabled
  children of the map that aren't the game's (`issecurevariable`), protected, numbered (pins) or ours are taken as
  elements, their icon at the icon size like any other (Ikar 2026-11-14: they were "way too small" scaled by their
  frame): the common button's ring and dark disc (MiniMap-TrackingBorder, UI-Minimap-Background) out of sight, the
  largest texture left taken for the icon, scaled to the size and centred on its place, clicks on it alone (hit rect);
  a fixed strata or level (KaLi Recipe's, LibDBIcon's) is unfixed while set, or it stood under the folder's list.
  Their addon moving them puts them
  back (a `SetPoint` hook), dragging is ours. One its addon hides takes no place (on the bar, in a folder) until its
  addon shows it again. « Le laisser à son add-on » gives one back as it was (`db.buttonsLeft`; dragged by the left
  button again only if its addon dragged it), the bar's menu takes it back. No other collector is looked for (Ikar
  2026-11-15: the MinimapButtonButton check and its chat line at login are gone). The map is looked at at login, 2 s
  and 8 s later, as LibDBIcon makes a button, and since the review of 2026-11-17 (D8) as each addon loads after that
  (`ADDON_LOADED`: on the next frame and once more 2 s later, however many load together): one loaded on demand made
  its button unseen, left on the map until the next login. Nothing is scanned at intervals (an older collector's users
  complained of a stutter from that).

## Borders and backgrounds

One look for the plate's edge and what it hugs (`UI/Border.lua`): the KaLi border. The plate's edge follows its
computed outline (`Geometry.Path`: the highest of `Geometry.Pieces` over each x, walls upright, curves in 2-unit
steps), as a band of quads cut along each bend (`Geometry.Band`, `Border.DrawBand`), each a texture whose corners
`SetVertexOffset` moves, carrying the border's profile across (`Border.Profile`, `Media/BandKaLi.tga`: outside first,
one block for each of 64 ways an edge can face, each quad taking the block its outer side faces), its shadow outside
the outline. Lit from the top left, as Blizzard's minimap ring (measured 2026-11-13: brightest at 120-150 degrees,
its highlights a third brighter than at the bottom right): a top edge's crest on its outer side, a foot's on its inner
side, the left walls lit, the right ones dimmer; an edge away from the light casts more shadow outside, one facing it
more on the plate. Its Edit Mode
section sets the **border** (size 50–100 %, opacity, colour) and the **background** (material, depth, colour,
opacity), the plate's fill included; by default Ikar's sizes and opacities (2026-11-15): the border 65 %, 75 %
opaque, the background stone at 50 % depth, 90 % opaque; its colours the « Blizzard - cuivre » style's since
2026-11-17 (Edit Mode's Style section), each its list's first: the border copper `c4977c`, the background walnut
`4a3a2a` (Ikar's dark bronzes `aa9273` and `3b3026` before, now second in their lists). The plate section sets the **corners** (round, square or bevelled, and their
sizes), for the plate and the status bars alike. Colours are `"rrggbb"`, chosen from presets or Blizzard's colour
picker (which redraws the whole HUD, the plate and the ring included).
- **What it hugs.** The chat and the damage meter: the plate takes them with no margin but the border's metal
  (`Border.Hug`), so its edge runs where their own border was; their own frame and background (Blizzard's chat
  textures, the meter's background, FlareUI's skins' backdrop pieces, never what sits on them: FlareUI's tabs) go
  see-through while the plate holds them (`Windows.lua`, alpha only, put back when it lets them go); no dark recess
  behind them. The minimap: by default (`minimapRing = "blizzard"`, Ikar 2026-11-14) Blizzard's own ring; with
  `"kali"` the border rings the map in place of Blizzard's ring
  (`Geometry.Circle`, a closed band), whole, over the plate's own edge where they meet (Ikar 2026-11-13: never follow
  the map's curve into the plate's edge). The map casts a soft shadow (`Media/Shadow.tga`) down on the plate. Round
  Blizzard's ring (or none), no slider since Ikar's tuning (2026-11-14, the map 158.4 wide: 8 at the top, 3 at the
  foot): the dome's edge stands 10 units past a map 198 wide (Blizzard's own size), clear of the ring's top ornament,
  and the ring at the foot (the carved neck, the pins round it) 3.75, both to the map's size (`Minimap.RingWidth`).
  The dome's disc is drawn only above the plate under it (`Geometry.Arcs`): where the plate fills up its sides, the
  disc over it doubled the material (a grey arc, Ikar 2026-11-14). The same rim round any ring, ours and Ikar's
  included (Ikar 2026-11-16: "Compared to the default blizard, our border rim is calculated to fit in"). Our ring and
  Ikar's are the map's own children, just over it, in UIParent's units (`SetIgnoreParentScale`, UIParent's scale):
  MinimapCluster is toplevel, so a click on the map raised it over all else in its strata, and our ring, beside it,
  went under the map (Ikar 2026-11-16: "when clicking on a map, it draws on top of the border, this is a bug"); a
  child rises with it, as Blizzard's ring does. Blizzard's cluster lays itself out round its own children only, so
  ours never stretch it.
- **No border:** the map's plaque (zone, clock) and the handles over the minimap's buttons. **The status bars** wear
  the thin border (`Media/BandThin.tga`, `LOOK.thin`, at 0.8 of the border's colour) as a band round them
  (`Geometry.Rect`, the plate's corner style,
  round corners at most 4): one line between two dark halos, as FlareUI's XP bar.
- **Corners.** Round: quarter discs and concave fillets (`Disc`, `Fillet`); bevelled: 45-degree cuts (`Bevel.tga`,
  pieces `bevel` and `slope`, grown so the cut stays parallel); square: none. The bands follow the outline, so one
  profile serves all three. The material over a right-hand cut or curve is masked by its own mirrored file
  (`FilletMirror`, `BevelMirror`): a mask in game ignored a mirrored `SetTexCoord`, leaving a black triangle under the
  border (Ikar 2026-11-14, seen with the border off).
- **No transition it can't draw (`Geometry.Smooth`).** A step lower than a corner and a fillet together, or than the
  border's depth, goes up to its higher side; a stretch too narrow for its own transitions (two fillets in a notch)
  goes up to the lower of its higher neighbours. Only ever up: the plate still covers all it took.
- **The border's look (`Media/BandKaLi.tga`, `Data/Look.lua`)**, drawn by `make_media.py` from one of
  `hud/bench/js/looks.js`' ten (`--look <id>`; bronze now): the metal's width, its profile (flat, round, bevel, groove,
  double, facet), its polish (brushed to mirror: a bright sky over a dark horizon), a dark line each side, a soft shadow
  outside and inside (3.5 units since 2026-11-13, Ikar: "not very visible"), its colour and corners as defaults.
  Light from the top left. No glow. Bronze is faceted and mirror-polished (`"profile": "facet"`, `"polish": 100`), so
  the plate's edge, the map's ring and the bars' end caps are; the thin border keeps its own.
- **Grain (Ikar 2026-11-14: "Flare adds a grain to the border?").** It does: FlareUI's border files vary about 5 % from
  texel to texel along the edge (measured on FlareUI-Thick/Thin/Frames). Ours draws `Media/BandGrain.tga` (white and
  black specks by their alpha, on the metal only) as a second band over the border, along the same quads, on the
  plate's edge and the map's ring. Tried as two sliders, then approved by Ikar in game (2026-11-15) and baked in, no
  longer an option: strength 35 %, specks 100 % long (as long as wide). `Border.GRAIN` (`strength`, `length`, both %)
  holds them; a saved `borderGrain` from the trial stays in the file, unread.
- **What was tried on 2026-11-16, and what came of it.** Ikar asked, after Blizzard's minimap and portrait rings ("a
  kind of triangular border"), for a shaped border and a light slider, then a polish slider ("Something that would make
  the border look more metallic?"), and tried two ideas of an outside review; all were options in a « DEV : essais »
  section of the dialog ("Mark them as DEV"), drawing the look as it was until he chose. His rulings ("Bake theses, also
  remove the dev"): the section is gone; each option's code, art and labels gone with it, and a setting a game saved of
  any cleared on load (`DB.Open`).
  - Baked in: **facets**: two flat faces, slope 1 each, meeting at a sharp crest 55 % across the metal from its outer
    side (`FACET_CREST`), the wide lit outer face, the darker inner one, as on Blizzard's rings
    (`UI-HUD-Minimap-Frame`, `UI-HUD-UnitFrame-Player-PortraitOn`), their raised triangle at north left out ("there is
    not on the character circle"); and **polish 100**: a mirror's sharp bright sky over a dark horizon, where brushed
    metal goes soft and even (`reflect`, linear in the polish; "Polish is perfect"). Both now the bronze look's own, so
    `BandKaLi.tga` is drawn with them. In game they were tried as the band brushed and its metal alone mirror-polished
    laid over it at the polish's share; the band drawn at 100 matches that at 100 within 0.09, at the metal's
    anti-aliased edges.
  - Kept as drawn: **the light** at 100 % (it was 50–150 %, the border, the background, the plate's lit lines and the
    art, the art brightened by its own copy added over it): no setting, as before.
  - Dropped: **V notches** cut into the border at intervals ("not great, remove them and any code associated");
    **a well**, a one-pixel rim, round each action button ("ugly"); **an inner shadow** along the plate's edge, fading
    in from the border, and **a one-pixel inner line** at the metal's inner side, the review's "recessed tray" ("no
    need": the band already carries a shadow inside its metal); **empty slots fainter** (left at 100 %: alpha only on
    Blizzard's `SlotBackground`, `SlotArt`, `NormalTexture`, whole under the pointer or with a spell dragged, it showed
    the plate under them, so they stayed dark).
- **The background (Ikar 2026-11-13: style, colour, opacity; the style imprinted into the colour):** the colour lit
  from the top, and a material over it: one of Blizzard's own tiling backgrounds (`ns.MATERIALS`, by atlas name,
  `C_Texture.GetAtlasInfo` giving its file; marble by file), tiling at its atlas size, fixed to the screen, masked
  round the plate's curves, desaturated and added (`ADD`) in the colour, scaled by its mean light so that colour and
  material together keep the colour's light; the colour under it gives up as much. Depth (`bgIntensity`) is the
  share the material carries (0 = plain colour); a vertex colour stops at 1, so a dark material under a light colour
  carries less. Materials: smooth, rock (the achievements frame's), stone (the bank's; the default), dark stone
  (Dragonflight frames'), marble, leather, wood, planks, masonry, parchment. Why not our own: procedural grains (round
  7) read as 1990s filters, at 18-28 % luminance spread where Blizzard's panel fills sit at 4-16 % (round 8 measure,
  Ikar: "extremely unappealing"). Colour presets are dark but not black (dark bronze by default; black removed, Ikar:
  "black should not exist"; charcoal is the near-black one). The dome's disc
  fills as its two upper quarters, its lower half lying on the arch: drawn twice, the material or a see-through colour
  would show.
- FlareUI's borders: its licence covers its code only, so its art isn't ours to ship.
- **The borders bench (`hud/bench/borders.html`): parked** (2026-11-13, Ikar: iterate in game). It predates the
  corners, the thin border, the hugging and the ring; `bench_plate.py` already exports one plate per look, the page
  doesn't read that yet.

## The windows and bags

- **Bags (`UI/Bags.lua`, `Core/Frames.lua`).** The bags always fold (Ikar 2026-11-15: the option did nothing off): KaLi
  HUD provides its own `"bag-arrow"` toggle (`KaLiHUD_BagBarToggle`) unless FlareUI's is already shown, and measures
  only the backpack and arrow — so neither a collapsed bag bar nor temporarily extending the bags ever grows a tall
  chimney on the HUD.
  `cleanBarArt` hides Blizzard's silver bar borders when running without FlareUI.
- **Windows (`UI/Windows.lua`).** `ChatFrame1` and `DamageMeter` get a cartouche or the fold arrow on top when
  covered; clicking it folds the window away
  without moving any Blizzard frame or touching `DamageMeter:SetMinimized` (which taints secret session values). Chat
  tracks unread messages while folded and can peek open while typing; the damage meter can unfold automatically in
  combat. In Edit Mode, folded windows show at full size. Folded, a window goes to alpha 0 by `SetAlphaFromBoolean`:
  FlareUI hooks the chat's `SetAlpha` and puts its own alpha back after anyone else's, so a plain `SetAlpha(0)` left
  the chat showing (Ikar 2026-11-13). What folds it is HIGH strata folded: the window's rows, see-through, still take
  the mouse (the meter couldn't be unfolded). The chat is the general dock: the plate measures
  the docked window whose tab is picked (`Frames.Shown`; the dock hides `ChatFrame1` behind another tab), and folding
  hides every docked window (Ikar 2026-11-14: with another tab picked, the chat left the plate).
- **Window cartouches (Ikar 2026-11-14).** One of eight pieces Ikar picked from his own art (`foldArt`: Ornate, Bronze,
  Steel, two each; since 2026-11-16 the Ornates only without their blue, two each, picked from bronze, silver and two
  golds tried each way; as drawn "not needed", a window folded by one keeps its piece in silver, `RETIRED_ARTS` in
  `Core/DB.lua`). His names: Ornate 1 - silver, its blue gray ("replace the blue with gray for the shading", lost in
  silver), its gold dark gold; Ornate 1 - gold, that one inverted ("silver gold for the first"): its gold leaves silver,
  shaded as its silver ones are ("a bit too white, should be more shaded, silvery"), its silver leaves and its
  scrollwork dark gold (its gold leaves gray, its silver ones kept, "not great"; on their own light all of them went
  white, "instead of inverting"); Ornate 2 - silver, its gold silver, its blue bronze ("the last version, bronze is
  good"); Ornate 2 - bronze, inverted ("bronze silver for the second"), its blue gray: its silver scrollwork, the art's
  right side, and its bar bronze too ("the right side mix of bronze and silver", "the bottom bar should be bronze
  too"), the braid on its ribbons silver ("should be kept silver"), its ring kept. `make_cartouches.py` recolours them
  at the art's own size, each colour taking its metal's at the same rank in OKLab, mean and spread of lightness and
  chroma matched, greys untouched but where asked; the braid is the gold the ribbon's blue closes over (gaps up to 10
  texels, grown 5 back over its crossings), so the ribbon's own edge stays with the scrolls; the bar takes the bronze on
  the scrollwork's light, so the two match; silver is the piece's own lit silver, shaded silver its silver scrollwork
  0.09 darker and its lightness 1.5 times as spread, gray the silver's colour on the blue's light, dark gold the
  piece's gold 0.12 darker
  and 1.2 times as rich (darker alone went olive), the bronze Bronze 2's metal (Bronze 1's is brass); same piece, same
  `base` and `rise`), the fold arrow (`Media/Chevron.tga`, a round-capped V, 0.75 of the ring) over a well in its
  ring, each cartouche's own (`well` in `Data/Cartouches.lua`: its ring's metal at a fifth of its light, 80 % opaque;
  `make_cartouches.py` clears the art's own dark fill inside the ring, its metal kept; Ikar 2026-11-14: solid black
  too heavy, half see-through too light), or `arrow`:
  the arrow alone, no text (24 across at 100 %, its V's foot on the flat line; Ikar 2026-11-14: "the simple are just
  the arrow"), under the same rule. "No drawing inside" (Ikar) was about the old chevron drawn inside the window over
  FlareUI's icons, not the ring: the cartouche without its arrow was an empty ring (the chevron in the window's header
  and the folded bar, with `foldHeight`, are gone). It sits on
  top of the window, over the window's middle, its flat line (`base` in `Data/Cartouches.lua`) `rise`
  units over the middle of the plate's metal on the window's top, so it follows the border's width at half speed;
  resized, it grows round that line. `base` and `rise` are fitted to Ikar's lifts in game at 100, 125 and 200 %, by
  least squares (2026-11-14: with `base` alone the cartouche still climbed as it grew; no straight line meets all three),
  then lowered by his lifts at the defaults (2026-11-15, size and border 100 %: Ornate 1, Ornate 2 and Steel 1 by 1,
  Bronze 1, Bronze 2 and Steel 2 by 2): a lift of 0 is where he set them
  (`foldArtLift` raises or sinks it from there; `foldArtWidth`, « Largeur du cartouche », its width as a share of
  the window's, half by default, below; from 2026-11-18 until then its ring one size on every cartouche,
  `foldArtSize`). Folded, the window leaves the plate: the cartouche alone stays, its flat line where
  the plate's metal lies under the window's middle, the window's name (and the chat's unread count)
  in its tooltip over what a click does. Folded, it's drawn behind the info bar since 2026-11-18 (Ikar: "when
  collapsed, can we put the cartouche behind the info bar ?"): BACKGROUND strata, level 20, over the plate and its
  border's frames, under the bar (LOW); it was HIGH, over the folded window's see-through rows, which still take the
  mouse. Its clicks are now taken by its `Catch`, an unseen button in HIGH over the part of it the bar leaves (from
  `InfoBar.Top()` up), with the cartouche's own scripts; open, it's as before, MEDIUM over the window. In Edit Mode it stays on the window shown at full size, its click as saved.
  The bar has no surface of its own (it's the plate's carved channel), so under the bar's items alone it still showed
  over the bar (Ikar 2026-11-19: "the cartouche not hidden, just drawn bellow icon, but on top of the bar, feel ugly
  still"): folded, it's now cut at the bar's top. Its art, well and arrow lie on `Body`, inside `Clip`
  (`SetClipsChildren`), as tall as the part over the bar, the part `Catch` covers; open, `Clip` is the whole cartouche.
  Since 2026-11-20 (Ikar: "instead of hiding the bottom, make a transparency gradient, till half the info bar ? see
  what this give us. All underlying button must stay clickable"): folded, what lies under the bar's top fades out down
  to the bar's middle and `Clip` stops there. The art and the well are each two textures (`Art` and `ArtFade`, `Well`
  and `WellFade`, `fadeDown` in `UI/Windows.lua`): the part over the bar whole, the part from the bar's top to its
  middle with its own texture coordinates and an alpha gradient; the arrow, over the bar, as it was. Still drawn under
  the bar's buttons (BACKGROUND under LOW), taking no click; `Catch` still stops at the bar's top, so the bar's
  buttons under the faded part keep their clicks. Not yet seen in game.
  Since 2026-11-17 two more, the styles' own, Ikar's art ("I downloaded 2 cartouche for the extra style, take the top
  one in each"): **Forest** (silver vines, glowing green leaves, a round ring) and **Rune** (carved stone, glowing
  runes, embers, a hexagon with a spike over its top corner). Their sheets (`gemini-7`, `gemini-8`) hold one piece a
  row on white, so `cut_art.py` takes them as one column (`COLUMNS`) and, on white (`ON_WHITE`), counts a ground the
  leaves' glow tinted, closed in by the vines, as ground (patches of 1000 pixels or more, at most 16 from white on
  average; the silver's highlights are smaller) and takes white off every light pixel it reaches from the ground through
  light ones (colour to alpha), so a glow fades out instead of standing in a pale patch; the dark outlines stop it (the
  Forest's cut otherwise since 2026-11-18, below). The other sheets cut as before, byte for byte. The Rune's ring is given by hand (`RINGS` in `make_cartouches.py`): the
  cut found the hexagon's opening below the spike; and its well is painted into the art over all the opening
  (`PAINTED_WELLS`, its `well` alpha 0, so the addon draws no disc): a disc of its half width leaves the corners
  clear. `base` is the Forest's bar's middle and the Rune's slab's foot, measured on the cut piece; `rise` 1.5, the
  others' middle, not yet tried in game.
  Since 2026-11-18 two more ("Two new cartouche, the first for steampunk, second for the silver", his sheets in his
  downloads, five pieces each; the top one of each taken, as before): **Steampunk** (brass rods, gears and scrolls,
  spear heads at its ends, a riveted hexagon) and **Silver** (a riveted silver frame with blades for wings, a round
  ring with a spike on top), worn by the Steampunk and Silver styles in place of Bronze 2 and the silver Ornate 2.
  Their sheets are `gemini-9` (black ground) and `gemini-10` (a grey ground drawn with cracks, the pieces numbered 1
  to 5, each ring filled white). For the latter `cut_art.py` takes 20..46 from its ground for clear..solid
  (`TOLERANCE`: its cracks stray up to 20, measured), drops a blob wholly inside a box round each number (`NUMBERS`;
  art a box reaches into stays; since the Silver took its second piece, every patch not clear wholly inside a box
  too, the number's faint edge under the blobs' 128: its 2 stood as a ghost, alpha up to 108), and opens the white rings (`WHITE_WELLS`): each big white patch the ground doesn't
  reach, out to the ring's black line (the median over 72 rays of the first pixel darker than 110), becomes black as
  see-through as it was white, so the ring is open and its soft edge a shadow, the JPEG's specks of colour gone. The
  other sheets cut as before, byte for byte. Both wells are painted into the art (`PAINTED_WELLS`: the Steampunk's a
  hexagon, the Silver's shadow running out to its ring), a painted well now going no further than 1.2 of its ring's
  radius (`WELL_REACH`, past a hexagon's corners at 1.155): this sheet's black lines, hardly darker than its ground,
  come out partly see-through (no longer, below), and the paint got out through them all round the piece. Every other
  texture is unchanged, byte for byte. `base` is the middle of the lowest long bar (the Steampunk's bottom rod, rows
  170 to 186; the Silver's frame's bottom bar, 258 to 292), so the ring stands over the window as on the others;
  `rise` 1.5, not yet tried in game. The Silver is its sheet's second piece since (Ikar the same day: "10-2 would
  work better than 10-1, it is flatter at the bottom"): its bottom bar rows 269 to 305 under a foot at 361, so
  `base` 74; at 100 % it's 224 long for 218.
  Then, the same day, Golden's and Astronomy's ("I added arts for the gold and the astronomy version, work on them",
  his sheets in his downloads): **Golden** (gold scrolls on a bar, small diamonds, a round ring; the second of five,
  V2: "let's go with 11-2 for the gold", in place of the top one) and **Astronomy** (blued steel, two crescent moons, two stars set with blue gems, filigree, a round
  ring with a spike under it; its sheet's one piece), worn by the Golden and Astronomy styles in place of the gold
  and the silver Ornate 1. Their sheets are `gemini-11` and `gemini-12`. The Golden's dark ground is lit unevenly,
  26 at its edges to 42 under its pieces, the art's soft shadows on it: `VIGNETTED` in `cut_art.py` measures each
  pixel from the ground where it lies (in blocks of 32 pixels at least nine tenths open ground, the mean of those
  near their upper quartile, so not a shadow; under a piece the ground around it, laid smoothly), so all of the
  ground goes clear and a shadow stays, black or dark brown and see-through; and by how much warmer it is, red over
  blue (V4's bar end, as dark as the ground but brown, had come out a fifth see-through). A gap the scrolls and
  their bar close in is a hole when it's no warmer than 25 on average, however much shadow lies in it (the ground
  there 11 to 21, lit by the gold; the art's own darks 30 and more, measured). Its V1 to V5 go as the Silver sheet's
  numbers (`NUMBERS`). The Astronomy's ground is pure red, lighter in its middle, darker down to a black band under
  it: `KEYED` takes the red off (how much redder than its green and blue a pixel is, against the ground's between
  the nearest pure red each side on its row; its steel and its gems have none), so its filigree's openings, its
  ring and its edges come out see-through, without red; a row with no pure red, the black band, is clear. Every
  other sheet cuts as before, every other texture unchanged, byte for byte. Both rings are round, so the addon draws
  their well (`well` alpha 0.8). `base` the middle of the lowest long bar (the Golden's rows 202 to 266 over a box
  ending at 289, its shadow under it: 54.5; the Astronomy's 301 to 321 over 471: 159.5, its ring and its spike
  hanging over the window as the Silver's do); `rise` 1.5, not yet tried in game. At 100 % the Golden is 363 long,
  the Astronomy 241.
- **The Forest and the Silver cut again (Ikar 2026-11-18: "some issue with half transparent part, especially jaring
  in the forest one, the last steel seems also cut and massacred").** The Forest's leaves had come out half
  see-through (white taken off their bright green as off the glow), the glow a green fog round them, and the white
  shaded under its vines, closed in by them, solid and pale over a dark ground. Now `SHADED` in `cut_art.py`: a
  near-white patch of 150 pixels or more closed in by the art is ground; the ground reaches through light greys (their
  brightest channel 200 or more, chroma under 12: a silver vine is darker) and through the glow's green however dark
  (12 over its red and blue, under 0.22 of its brightest channel, that 130 or more: a leaf's green is more saturated,
  its outline too); what it reaches is shadow, black as opaque as it's dark (its brightest channel short of 240), its
  tint, chroma 12 to 28, going clear. The leaves stand solid with their outline, the glow and its sparks gone (blobs
  under 400 pixels dropped). A leaf the glow no longer holds on goes to the piece whose rows it's in (it went by its
  middle's height, which gave the lower Forest's top leaves to the upper one). The Silver's dark outlines and grooves,
  hardly darker than its ground, touched it and went with it: see-through lines across its bars, its filigree in
  pieces. Now `OPENED`: its ground only where a disc of radius 4 fits in ground-like pixels, reached from the sheet's
  edge or a hole of 400 such middles as flat as the ground, then grown back by 4, so a line narrower than 9 pixels
  stays art; its well, painted, a little darker (0.085 for 0.102, its metal measured whole). Every other sheet cuts
  as before, every other texture unchanged, byte for byte; the Forest's piece and ring as before. And a cartouche's
  art is filtered `TRILINEAR`, as Blizzard's own scaled map art is (`MapCanvasDetailLayer`), for its thin lines not
  to break up where it's drawn smaller than its texture (its ring 41 to 80 texels across, 34 UIParent units at
  100 %: smaller wherever a unit is under 1.2 to 2.4 texels, at a small size, on a low screen or a small UI scale; a
  UIParent unit is the screen's height times the UI scale over 768 pixels, so on most screens it's drawn larger, and
  the filter does nothing). Not yet seen in game.
- **The Forest's glow back, as a light (Ikar 2026-11-18, of the cut above: "where are they ? They all should have
  half see through parts").** Its glow and sparks had gone; the shadow under its bar and inside its ring stood solid
  grey down to where it passed 200; and its crest's two side leaves had been see-through since the first cut (their
  white lines taken for holes, the ground run in through them). The sheet draws its glow on white as a green darkening,
  so taken off white it darkened what's under it, the fog. `SHADED` now: a pixel the ground reaches is a black shadow
  and a light, `GLOW_RGB` (150, 245, 130) as opaque as 0.8 of its darkest channel short of white, mixed by how much
  greener than its red and blue it is (6 to 20): over a dark ground the halo lights it, over a light one tints it. The
  reach takes a step only down (at most 6 lighter) or between two pixels both 200 or more, so it follows a shadow to
  the outline and can't climb back into the art at a thin tip (it went into the crest's silver at its leaves' points,
  then down its greys). It goes through light greys as before; through a grey down to 45 with its red and blue within
  3 (the shadows are that grey; the silver vines are cyan, the brown one warm), greener by 3 at most, and from 80 up by
  a tenth of its green besides (a glow over a shadow; the green vines' darks are as green, darker); and through the
  glow's green from 130 to under 250, so not a leaf's heart. A near-white patch the art closes in is ground if a pixel
  of it lies 5 or more from its edge and its blue and red are within 3 on average: the silver's highlights are thinner
  or cyan, the crest's lines 2 to 3.3 deep, the leaves' hearts yellow, the true holes 5 to 27 deep (measured); the
  narrow white between the vines just over the bar, 2 to 3 deep, stays solid as before. The sparks stay (blobs of 30
  pixels and up, as on other sheets). Its foot is 5 rows higher (the shadow under its ring now see-through), so its base
  58 for 63, the same row on the window's line; its ring measured to its metal, 183.5 for 175.5 (the shadow inside its
  top no longer solid), so at 100 % it's 251 long for 263. Every other sheet, piece and texture unchanged, byte for
  byte. Not yet seen in game.
  Since 2026-11-18 three more, each made from a minimap ring with the cartouche prompt (a straight rail as long as the
  piece, end caps, the ring hanging a little under it; five a sheet, one column on white): `gemini-13` (steampunk),
  `gemini-14` (fire), `gemini-15` (gem), cut as the Rune's (`ON_WHITE`). Ikar's picks ("For the steampunk, the last,
  replace the existing", "Last for fire", "4th for the gem"): **Steampunk** now 13-5 (a gear-toothed ring, copper
  filigree), its id kept so the Steampunk style and whoever chose it get it, its ring round so its well the addon's
  disc (no longer `PAINTED_WELLS`); **Fire** 14-5 (lava knotwork), in the list, no style wearing it; **Gem** 15-4
  (a crystal fan in leaves), the Gem style's own in place of the Ornate 1 in gold. `base` the middle
  of each rail, measured on the cut piece (88, 105.5, 105.5); `rise` 1.5. `cut_art.py` and `make_cartouches.py` take
  names now (only those redone, the others' entries kept). Not yet seen in game.
  The Gem's texture a BLP with its mipmaps since (Ikar the same day: "the gem one has some resizing artifact,
  aliasing"): the texture itself was clean, its thin light lines on gold breaking up where the game draws it smaller
  (its ring 61 texels across for 34 units); `TRILINEAR` asks for mipmaps, and a TGA has none. `make_cartouches.py`
  writes the ones in `MIPPED` as BLP2, uncompressed BGRA as Pagle's minimap icons, every level halved from the one
  above, colour weighted by alpha, down to 1 by 1, and drops the TGA (the game finds a path with no extension as
  .blp first). The others as before. Not yet seen in game.
  And the Rune's from the same prompt since ("added the new runnic also", "for the rune, the last"): `gemini-16`, cut
  as the others on white, its fifth (wolf heads by the ring, an amber gem under it) in place of gemini-8's hexagon,
  its id kept; its ring round, so `RINGS` holds none now and its well is the addon's disc (out of `PAINTED_WELLS`);
  `base` 154.5, its rail's rows 301-340 under a foot at 475. Not yet seen in game.
  Since 2026-11-20 the Rune's and the Astronomy's from prompts in two parts, strict (the ring or hexagon, its empty
  opening, symmetry, the bar and what may hang under it, the sheet, the white) and free (the rest, five as unlike as
  can be): the Rune's the third of `gemini-17` ("changed runic take the third for the game"), a hexagon again, its
  ring by hand in `RINGS` at its flat sides' half width (108; the cut took its corners', 127) and its well painted
  (`PAINTED_WELLS`), `base` 138 (rail rows 280-340, foot 448); the Astronomy's `gemini-18`'s one ("and new astronomy
  in"), its opening a little taller than wide, so its ring by hand at its half width (347; the cut took 369) and its
  well painted too, `base` 130 (bar rows 941-1009, foot 1105). Its ring big for its length, it is about 4 rings long
  where the old one was 7. Ids kept. Not yet seen in game. The Rune's foot cleared since (Ikar the same day: "for the
  runic, can you remove the decoration at the bottom of the hexagone ?"): `CLEARED_FEET` in `make_cartouches.py` takes
  off what lies under its rail (row 341) outside the hexagon's lower edges (row 407 at its middle, 0.6 higher a pixel
  out, measured where nothing hangs), the plate and the two tabs; its `base` unchanged, the texture as tall.
  The Steampunk's from the same two-part prompt since (Ikar 2026-11-20, to match his new steampunk minimap ring: "a
  hexagone in the middle, but flat part bellow above. The rest, I want him to be creative"; then "use the last"):
  `gemini-19`'s fifth (lit bulbs on springs, copper pipes, two gauges), an octagon flat on top and bottom where a
  hexagon was asked. The cut's ring is its flat sides' half width (143-144 each way, the diagonal sides 148-150), so
  no `RINGS`; its well painted (`PAINTED_WELLS`), a disc leaving its corners clear; `base` 36.5 (rail rows 372-421,
  foot 433, the octagon's foot on the rail's, only the end caps lower). Its id kept. Not yet seen in game.
  The Astronomy's again the same day ("I downlaoded another one for astronomy, replace it"): `gemini-20`'s one, moon
  phases in rings either side, its opening again a little taller than wide (1196-1841 across, 252-931 down), so its
  ring by hand at its half width (323; the cut took 339) and its well painted; `base` 263.5 (bar rows 889-950, foot
  1183: its ring and the point under it hang lower). Its id kept. Not yet seen in game.
  The Steampunk's again the same evening ("new cartouche for steam punk, number 2 and 5", then "keep steampunk 1,
  rename it to steampunk, remove the 2"): `gemini-21`, five from the same prompt, octagons again; its second (lit
  tubes either side, gauges, springs), its id kept, so the Steampunk style and whoever chose it get it; rail rows
  376-423, foot 436, `base` 36.5; its well painted, its ring the cut's (142.5). The fifth, a Steampunk 2 for an
  evening, gone: one folded by it takes the Steampunk's (`RETIRED_ARTS`). Not yet seen in game.
  The Golden's the same evening ("new gold cartouche in", the fourth of five picked: a shield over the ring, acanthus
  wings, rosettes): `gemini-22`'s fourth. Its opening round, its ring by hand (800, 227.5, 112; the cut took the
  largest disc clear of the shield's tip, which dips 30 into its top); its three leaves hanging under the ring's two
  curls cleared ("can you remove the 3 little leaves on the bottom ? it would get too low"; `CLEARED_FEET`: 743-857
  across, cut level at row 410, the band's foot either side of them); `base` 117.5 (rail rows 334-359 where it runs
  alone at its ends, foot 464). Its id kept. Not yet seen in game.
  The Astronomy's again ("and a new astronomy, the last one"): `gemini-23`'s fifth, a twelve-sided ring with the
  zodiac's signs between two four-pointed stars, orbits and constellations; its opening round (122-124 each way), so
  the cut's ring, no longer one by hand; its well still painted; `base` 52.5 (rail rows 360-381, foot 423, the ring
  hanging lower). Its id kept. Not yet seen in game.
- **A cartouche a share of its window's width (Ikar 2026-11-20, asked whether each should be half its window's
  width, its ring then changing from one window and one art to the next: "Yes, keep the slider, but it shoudl show
  relative size, default to 50%").** `foldArtWidth`, « Largeur du cartouche », 20 to 100 % of the window's width, 50
  by default; its height and its ring as its art has them there, so each window's and each art's ring its own; the
  arrow alone its own size at 50 %, grown or shrunk as the slider is from it. A size saved before (`foldArtSize`, the
  ring's) is dropped when the saved data is read, the default taken: it said nothing of a width. From 2026-11-18 until
  then, a cartouche was sized by its ring ("Make the button the same size, allow the length to varry"): 34 UIParent
  units across at 100 % on every cartouche and over both windows, its length its art's, so over a window narrower than
  its cartouche it ran past it (at 100 % the Steampunk about 420 long, the Rune 292). Half the window's width before
  that, as again now: on a chat 451 wide, a ring of 34.5 for Bronze 1, 35 the Silver, 18 the Steampunk then. Its flat
  line is set in UIParent's units whatever its size, so Ikar's lifts hold.
  `hud/tools/cut_art.py` cuts his sheets
  (`hud/art`) for the cartouche bench; `hud/tools/make_cartouches.py` writes the picks as `Media/Cartouche*.tga` (512 by
  128, turned over as the bench showed them) and `Data/Cartouches.lua` (where the piece and its ring are).
- **The review of 2026-11-20 (Ikar asked for one: "usability, convenience, good presentation, correct name and
  texts"; all its points taken, but « Congés »: "keep conger").** One thing, one name: the HUD's four parts by the
  same words on the options page and in the dialog (« Afficher la plaque », no « de bronze », eight of the nine styles
  being no bronze; « Prendre en charge la minicarte »; « Repli des fenêtres »; « Afficher la barre d'informations »,
  with its tooltip), the info bar « Barre d'informations » in every French text (the bar's menu's title had
  « … et logements »), « add-on » in every French text, the progress bar's end cap « Embout ». The padlock's tooltip
  says its state (« Emplacements verrouillés » shut: its title was the menu box's « Verrouiller les emplacements »),
  what that state allows (open, it still said to unlock), then its clicks at its foot. The hints: le, la, les before
  what a click opens (« [left] la carte du monde », « les monnaies », as the currencies' own said), an infinitive for
  what it does (« couper le son »), and the same words for the same right-click everywhere. Plainer labels in the
  dialog: « Taille de la bordure », « Couleur du fond » and their like, « Nombre de coins max. », « Creux autour des
  barres », « Taille du cycle jour/nuit », « Boutons de zoom », « Barre et carte en creux »; the text sizes stay
  « Taille » (Ikar's of 2026-11-15). The dialog's « Fenêtres et sacs » is « Fenêtres », the box hiding Blizzard's
  frames round the bars, bags and micro menu under « Bordures et fonds ». The options page's last header « Aide »
  (« Diagnostic », holding the bug report alone since its status row went). A folder's list settings in one submenu,
  « Liste » (its menu had some sixteen entries), its count « Éléments par colonne » when the list runs down. The bar's
  menu opens on what it shows, undo and redo last (they opened it, greyed most of the time). `/kh help` names the
  player's commands alone (options, Edit Mode, status, report, errors, export, import; the tools for testing and
  debugging still answer). The TOC: « A metal base », its category « User Interface » (« Action Bars » said it ran
  them). The changelog says what the first version has, by part, not how it came to be.
- **A bundled folder made again (Ikar 2026-11-20: "and I still don't see how to bring back my emote folder").** A
  locked one not there (deleted before « Retirer » took its place) is made again at the next login (`Seeds.Sync`).
  « Add-ons » or « Suite » gone (renamed, it is the player's) is listed among the folders of the bar's menu, by its
  name, unticked (`Seeds.Missing`); ticked, made again as made (`Seeds.Restore`), one action, undone from the bar's
  menu.
  « Suite » only once made (`db.seeds.overflow`), as it waits for the first time something doesn't fit; « Add-ons »
  where new addons land again while no other folder takes them.
- **The group's markers' two clicks (Ikar 2026-11-20: "they shoudl be left click on target right click spell on
  ground").** A left click `/tm n`, the sign on the target; a right click `/wm n`, the marker on the ground through the
  game's targeting circle, no `[@cursor]` (on a button the pointer is never on the ground); each button said by its
  description (« Marquer la cible », « Poser au sol »). Those saved as made before, `/wm [@cursor] n` on the left alone,
  are made as now at the next login, as all a locked folder holds.
- **The loot set from its item (Ikar 2026-11-20: "the group loot shoudl also allow to change it when clicked").** The
  group's leader's left click opens the rules as the game's portrait menu has them (Blizzard_UnitPopup's loot
  buttons): each method the game offers here (`C_PartyInfo.IsLootMethodAvailable`), the master looter the leader
  himself, then the threshold from the unusual to the epic in their colours, but under personal loot
  (`C_PartyInfo.SetLootMethod`, `SetLootThreshold`, called on the click, as Blizzard's menu does: not protected, its
  restriction on secret arguments). Anyone else's click opens nothing; the tooltip says the leader sets them, and to
  the leader what the click does. Not seen in game.
- **The sounds' play buttons (Ikar 2026-11-20: "the two sounds shoudl have a play button next").** By each sound's
  dropdown on « Comportement et sons », the button Blizzard's Cooldown Viewer gives a sound alert
  (`common-icon-sound`, its pressed and disabled states, its highlight at 0.4, 25 across), its tooltip the game's
  « Lire un exemple »: it plays the sound picked, opening's, greyed on « Aucun ». A choice row's `play`, `playTip`
  and `canPlay` in `shared/addon/Page.lua`, the three addons' page.
- **« Tout effacer » clears the signs too (Ikar 2026-11-21: "tout effacer remove only the one on the ground").** Its
  macro `/cwm all`, then `/click KaLiHUD_ClearSigns`: a button of the addon's (Social.lua), sizeless and never seen, a
  secure one of the game's own action for it (SECURE_ACTIONS.raidtarget's "clear-all", RemoveRaidTargets, the raid
  frame's reset; restricted, hence the secure button), which no slash command has; acting on its release, as /click
  sends it. One saved as made before, `/cwm all` alone, is made as now at the next login, as all a locked folder
  holds.
- **The zone's PvP state where the game names no faction (Ikar 2026-11-21: "Aucun status jcj ... why ?").** A
  friendly or hostile zone whose faction `C_PvP.GetZonePVPInfo` leaves empty (a PvE realm: Blizzard's own zone text
  then gives its colour alone) said « Aucun statut JcJ » in green; now the game's « Territoire » of the player's
  faction where it's friendly, of the other where it's hostile (`UnitFactionGroup`, `FACTION_ALLIANCE`,
  `FACTION_HORDE`). « Aucun statut JcJ » only where the game gives no state at all.
- **The map the player's key opens (Ikar 2026-11-21: "qhen opening the map, we open the default map, not the one that
  open with m shortcut").** Zmap takes the world map's key with an override binding that clicks a button of its own
  (`SetOverrideBindingClick`), which `ToggleWorldMap` never reaches. The four that open the map (the zone, the
  coordinates, the zone's PvP state and levels) follow the key's binding as pressing it would (`GetBindingKey`,
  `GetBindingAction` with its overrides): a button's click, an addon's and not a secure one; else the game's map.
- **The info bar without the plate (Ikar 2026-11-20: "when disabling the plaque, the info bar, if still enabled,
  shoudl stil lshow it background as before").** With the plate off and the bar on, `Plate.Redraw` draws the bar's own
  strip (`barAlone`): the outline of a plate with nothing on it, as tall as the bar and its border, so the bar keeps
  its background, its material, its border along its top and its floor; nothing round the frames, the map or the
  windows, which keep their own frames. Both off, nothing.
- **Folding animated (Ikar 2026-11-15: "no fading, I want folding").** `foldAnim`: on or off, a checkbox (Ikar
  2026-11-18: "remove the non darkening folding, replace the list with a checkbox"; « Store assombri », « Store »
  or « Aucune » before, a saved « Aucune » now off, either blind on), on by default: the darkening blind. The window goes at once, as folded; then its place on the plate comes down into the
  plate: `Windows.AdjustSpan` gives the plate a span whose top runs from the window's top to under the plate's foot
  (the info bar's top less the border's metal, so the place sinks below the plate's own edge and the end shows no
  jump), the cartouche riding its top. Only that place changes (Ikar 2026-11-15: folding mustn't change the layout):
  the plate as frozen, its corner limit included, is spliced with the one the folding window gives
  (`Geometry.Splice`) only where the plate changes for that window (`Geometry.Differ` of the outlines with it and
  without it). On its way, its place is left out of the rule that lifts a step too small for the border's curves to
  its higher side (`Geometry.Smooth`'s `moving`; Ikar 2026-11-16: near the foot, the border beside it "snaps for a
  couple of frames ... looks bad"): it never lifts what's beside it, nor is held at a taller neighbour's height; its
  small steps are drawn as they come, the curves shrunk to them (`Geometry.Pieces`), and sunk under the plate's floor
  it goes into it, as at rest. **Not linear (Ikar 2026-11-15: "could we enhance the collapsing animation? Make it not linear?")**:
  a sheet's (`Windows.Ease`; Ikar 2026-11-16: "when it collapses it should end the motion more slowly ... I am sure
  folding unfolding animation have some golden value"): iOS's sheet curve, cubic-bezier(0.32, 0.72, 0, 1), over 0.5 s
  both ways, as Vaul's drawer has it. The place never leaves the screen, it comes to rest at a new height, as a sheet
  or a drawer does: it sets off at once, as the click asks, is 90 % there at a third of its time and slows into place
  over the rest. Material 3's emphasized decelerate (0.05, 0.7, 0.1, 1) over its long 500 ms and SwiftUI's default
  spring (critically damped, 0.55 s) have the same shape and length. Tried first: the time's share cubed, an ease-in
  (for what leaves the screen: the fold ended at full speed), then a cubic ease-out over 0.25 and 0.35 s ("still too
  fast at the end ... barely noticeable": 90 % there at half its time, the rest over 0.12 s). Turned back on its way,
  a fold sets off back from where it stands (`Windows.Step` keeps where it is and finds its time's share from it). Darkening, that place grows
  darker as it goes and lighter as it rises again (Ikar 2026-11-15: the accordion's creases, tried first, "look
  horrible"), from the plate's foot to its top, black over it up to 50 % as far as it went (`Windows.Shading`,
  `Plate`'s `drawFoldShade`, `FOLD_DARK`; Ikar 2026-11-15: "the bottom stays clear, and the inside darken too much,
  half darken will be enough": it covered the window's own span alone, up to 70 %; 35 % then, 50 % at Ikar's word
  2026-11-16). Unfolding, the place rises first and the window shows again once it has risen 95 % (`SHOW_AT`, at
  about half its time; Ikar 2026-11-16: "show the panels a bit earlier, at the end of the transition"), not after the
  slow end of its rise. `Windows.Begin`, before each layout, sets a fold off when what it should be changed (a click, typing, a
  fight, leaving Edit Mode), animated if the window stands on the plate; in Edit Mode it's there at once. A frame's
  `OnUpdate` (`Windows.Step`) moves the folds and redraws the plate fast each frame, in full at the end, then stops.
- **Sounds.** A click on a cartouche plays the fold's sound (`foldSound`: the tome put away folding and drawn
  unfolding, Ikar's pick among the game's paper sounds; parchment, quest log, page, book, cloth, crumpled paper or
  none); a window unfolding by itself (typing, a fight) is silent. A click on a folder plays the folders'
  (`folderSound`: the housing sub-menu's, Ikar's pick; click, tab, button, waypoint, bag or none); opening on hover or
  shutting on leaving is silent. They are kits of Forever's SoundKit table (`ns.FOLD_SOUNDS`, `ns.FOLDER_SOUNDS` in
  `Core/Init.lua`), by SOUNDKIT's name where the game gives one, which `run_tests.py` checks against this build's
  table; a sound picked in the Edit Mode dialog plays.

## Edit Mode, options and live tracking

- **Live drag tracking (`UI/Plate.lua`).** While Edit Mode is open, and then alone (since 2026-11-15, the plate static
  outside it; a button held on a frame outside Edit Mode followed it before), an `OnUpdate` check that allocates
  nothing (`Plate.Moved`, the same reading of the frames as the plate's own) redraws the plate on every frame as bars,
  windows or the minimap are dragged or resized; the status bars, their bubbles and the windows' folds are touched
  only where they changed. Outside Edit Mode, `OnUpdate` is off.
- **Edit Mode dialog (`UI/EditFrame.lua`, `UI/EditPanel.lua`).** Selecting the **KaLi HUD** strip along the foot opens
  `KaLiHUDEditModeDialog` (`Shared/Dialog.lua`) beside Blizzard's Edit Mode window, its top level with it, on the side
  away from the screen's nearer edge, as KaLi Quest's opens by its tracker (Ikar 2026-11-15: it opened over it), with
  nine collapsible sections: Style (below), Plate & Reach (vertical `reach`
  decoupled from horizontal gap `bridge`, corners, fillets, the carved channel), Borders & Backgrounds,
  Component Margins (action bars, their padding, menu/bags, status bars), Minimap (the pockets' marks too), Windows &
  Bags, each status bar's own
  (« Barre de progression 1 », « 2 ») and Info Bar, with `Revert` and
  `Defaults` (each draws the HUD once, however many settings it puts back). `Defaults` asks first, as the game's own
  settings do, saying every setting changed is lost (Ikar 2026-11-16: "The Par defaut in the menu should warn the user
  that he will lose the changes"); an answer given once a fight has greyed the window does nothing. Each open section
  ends in a line of its own « Annuler » and « Par défaut », each half the row, asking nothing ("add 2 button per
  section, cancel and default, no warning. Can we make them in one line?", the dialog's `sectionButtons`): « Annuler »
  puts back that section's settings as they were on entering Edit Mode, a status bar's place too (the section's
  `extra`), lit only when the section changed; « Par défaut » sets that section's to their defaults, lit only when one
  isn't.
  **Style** (`Data/Presets.lua`; Ikar 2026-11-16: "make presets ... centered around a minimap style, and a color"),
  first and open at first ("help speed up the setup"): one « Préréglage » list of nine styles, each a minimap ring and
  a colour: « Blizzard - cuivre », « Argent », « Doré », « Forêt - vert », « Rune - taupe », « Steampunk - bronze »,
  « Gemme - rose et or », « Astronomie - bleu », « Feu - rouge » (2026-11-18: "add the fire - red as a preset": the
  fire ring and cartouche, an ember red border b4544a, charred dark stone 2e1f1c, both added to the lists, without names until 2026-11-24: the lists showed their strings' keys, `L` giving a missing one back, now « Rouge braise » and « Pierre calcinée », and the smoke checks each colour of both lists has one (Ikar: "fix the color names for firez they use a code right now, looks bad")). The Gem's background a dark old rose `5e4a48` since 2026-11-20 ("The gem style shoudl have darker background, text unreadable other wise"), the light one `a88c86` its hue's from its art's pearl pinks and champagne gold from 2026-11-19 ("too dark for the gem style, is shoudl be much clearer, in the colors of the art"), the dark bordeaux `3a2226` before, kept in the list. A style sets the look alone, `PRESET_KEYS`: the map's ring, the
  border's colour, the background's colour and material, the windows' cartouche and the corners' shape ("I believe
  yes", 2026-11-17); never a size, a margin, an opacity or what a bar shows, so no style moves anything. Each border
  colour is its ring's own metal, sampled from its highlights (verdigris `a0b4a8`, taupe `9a8b74`, rose gold `c9a08f`
  added to the list for them). The first is the defaults' (Ikar 2026-11-17: the defaults "blizard"): copper `c4977c`
  where the border was his dark bronze `aa9273`, walnut `4a3a2a` where the background was dark bronze `3b3026`, Bronze 1
  for the cartouche; his dark bronzes live on as « Steampunk - bronze ». The list shows the style the look is, every
  value it sets as it set it, else « Personnalisé ». Picked, a style applies at once, unless it would replace a value
  the player changed ("a warning that the changes may be lost should be given. Only for options the preset touch"): a
  value is the player's when it is neither what the new style puts nor what the style last applied put
  (`options.preset`, the first's when none was), and none is while the look is a style's as it set it, so going from
  one style to another never asks; then a question names those settings alone (« Appliquer le style « Forêt - vert » ?
  Ces réglages, que vous avez changés, seront remplacés : Couleur bordure. »), Oui or Non. The section's own
  « Annuler » puts back every value a style sets and the style last applied (its `extra`), a look of the player's own
  too; its « Par défaut », and the window's, the Blizzard style. Cartouches in a style's colour that don't exist yet
  stand in with the nearest (copper: Bronze 1; pink and gold: Ornate 1 - gold; blue: Ornate 1 - silver, until
  Astronomy's) until Ikar's own ("wait for the dedicated ones"); Forest's and Rune's are his (below), and since
  2026-11-18 Steampunk's and Silver's, then Golden's and Astronomy's (below).
  Gone (2026-11-13 review): the plate's opacity (the background's and the border's say it), the slots'
  bronze rim, the coordinates on the map (an element now), centring under the minimap (the zone always is).
- **The page in the game's options (`UI/Options.lua`).** Under `Options > AddOns` and the addon compartment, with a
  button to jump straight into Edit Mode on KaLi HUD, info bar item toggles and their reset, status diagnostics and
  bug reporting. Since 2026-11-16 a frame of the addon's own (`Shared/Page.lua`), laid out as Blizzard's pages, and no
  longer rows in Blizzard's own list of settings, where the game blamed KaLi Quest for what its Social page did
  (2026-11-12; KaLi Quest's record has the account).
- **Self-contained media & licence (`KaLiHUD/LICENSE`, `hud/tools/make_media.py`).** The licence says it as it is
  since 2026-11-16 (it said all media were drawn by the tools), and since 2026-11-22 names the art's origin without
  counting it (it said six cartouches, when 16 cartouches and 17 rings shipped). All textures (`Disc`, `Fillet`,
  `Bevel`, `FilletMirror`, `BevelMirror`, `Shadow`, `Ring`, `BandKaLi`, `BandThin`, `BandGrain`, `Bar`, `BarStriped`,
  `Lock`, `Unlock`, `Chevron`, `Icon`) are generated procedurally; the cartouches and the minimap rings are cut from
  images Ikar generated with Google Gemini (`hud/art`, not published; each sheet carries Google's C2PA credentials,
  `trainedAlgorithmicMedia`); the background's materials are the game's own, never shipped; MIT-licensed patterns
  adapted from Malkkav's FlareUI are attributed in `LICENSE`. The README's « Credits » (Ikar 2026-11-24: "The inspired by should be a separate section, look
  how flare UI did it. It should be to honour other modders, important"), after FlareUI's own: each work linked
  with its author and licence and what KaLi HUD owes it, an idea said to be one: FlareUI (its look, its XP bar, the
  code above), Titan Panel (the info bar, the idea only), SexyMap (the minimap's borders, the idea only). Then, at his "Ok", from this log: SpartanUI (the status bars under the bars, by wutname1)
  and SinStats Character Stats (the thresholds against a target of another level, by Sinba), ideas only.

## Build order

1. **The probe** (`addon/KaLiHUD_Probe`, `/khprobe`): the frames' names, sizes and Edit Mode systems on Forever, a bar
   moved as a drag would, blocked actions after it, the broker objects present, the calls the items need.
2. **The art and the info bar together**: the addon in the family (shared code, tests, runner, links), the plate and
   its drawing, the info bar with plugins and its items, the status bars.
   Built 2026-11-13 with spots and pins in Edit Mode; Ikar tried it in game and ruled them out the same afternoon.
   Rebuilt reactive the same day, checked offline only (`python -I hud/tools/run_tests.py`: 20 tests, a smoke session
   on a fake game holding Ikar's own layout from his probe, the next session from its saved file). Not yet seen in
   game. My calls, for Ikar to confirm or change:
   - The reach is 40 units: Ikar's bars stand 27 above the info bar and 1 to 14 above one another; his chat, in the
     top right corner, is far out of it.
   - Gaps narrower than the reach close; wider ones stay down to the info bar.
   - The status bars (12 high) take the width of the level bars above them. The info bar is 22 high; right click on it
     says where each item goes (left, centre, right, hidden) and in what order. Other addons' objects go on the right,
     a launcher as its icon alone. Titan Panel, if still on, shows KaLi HUD's items too.
   - An earlier build's pins stay in the saved file, unread.
   - Since 2026-11-16 KaLi HUD is in the family's `tools/` (`paths.py`, `shared.py`, `run_tests.py`, `breaks.py`
     with `tools/breaks/hud.py`) and the README's table; `tools/sync_shared.py` writes its copies of the shared code,
     and `hud/tools/sync_shared.py` is gone.
3. **The minimap's dressing and the windows' fold.**
4. **The options page and the bench** (the draft moved to `bench/`).

## Open questions, for the probe

Secure folders and macros (2026-11-16), checked offline on a fake game that blocks what this build's API docs mark
protected (and `SetAttribute`) on a protected frame in a fight, with Blizzard's snippets, auto-hide and secure action
emulated; not yet seen in game:

- A folder holding macros opens and shuts in a fight by click and by hover, the auto-hide shutting it, and its
  macros run; no « Interface action failed because of an AddOn ».
- What a secure button holds changed in a fight: the folder's well shown or hidden, its icon not moved (inferred to be
  allowed; the icon's offset waits for the fight's end).
- The bar (parent of secure buttons) and a folder's list report themselves protected (`IsProtected`).
- Nothing blocked while texts update in a fight, nor when it starts with a layout waiting.
- The click that ends a drag: whether the game sends it (the hub undoes its effects if it does).

The bar's other items, folders and separators (2026-11-16), checked offline only:

- Attributes in a fight: the game's values hidden (secret), each keeping its last text, read again after; no Lua
  error.
- ~~`C_Map.GetMapLevels` answering on Forever's zones~~: it doesn't, the build's data giving none (2026-11-18); the
  zones' levels are now the Group Finder's (`Data/Zones.lua`). A cave's map giving its zone's (a micro map's
  parent, `C_Map.GetMapInfo`'s `parentMapID`). Fishing's bases being Forever's too (the original game's: a cast
  getting away below base + 95, none landing below the base); `GetInstanceInfo`'s eighth value a dungeon's map
  (36 the Deadmines); `GetSubZoneText` and `C_Map.GetAreaInfo` naming Azshara's Bay of Storms alike. The statistics by id
  (`GetAchievementInfo`, `GetStatistic`) known; `C_GuildInfo.GetMOTD` readable (its docs mark it restricted).
- The macros of the group's folder: `/wm n` bringing the game's targeting circle, a click on the ground placing a world marker on Forever (`[@cursor]` until 2026-11-20, Ikar: "the cursor will be by definition at the button", never on the ground; saved ones made as now by their locked folder), in the order assumed (1 the
  blue square... 8 the skull), `/cwm` with the game's « tout »; `/cdm` opening the cooldown manager; `/appel`,
  `/countdown 10`.
- `C_Calendar.OpenCalendar` at login changing nothing the player sees; today's events and invitations right.
- The macro editor's icon opening the library over it, beside it.
- Folders in folders, in the game's restricted code: a handle's `GetFrameRef` on another frame's handle, two handles
  of one frame equal, `RegisterAutoHide` again on a list already registered taking the new rects, a list hidden in its
  own `_onhide` snippet's `sub:Hide()` running that one's; in a fight as out of it.
- One folder open at a time through the registry (`SecureHandlerBaseTemplate`'s refs read from a button's snippet);
  `PlayerInCombat()` in a snippet true from a fight's first moment; a list registered with the auto-hide during
  `PLAYER_REGEN_DISABLED` shutting once left, and staying open after `UnregisterAutoHide` at the fight's end.
- The folders' lists' darker floor beside the carved info bar: the same shade to the eye.
- One right-click (2026-11-17): a right-click on the tracking button and the compartment opening their hub menu and
  not theirs, the calendar's not opening the calendar; another addon's launcher's and map button's own right-click
  untouched while shut. The padlock's cap to the eye, shut and open, at the info bar's sizes 6 and 20: the gold
  clearly seen, its aura soft round it, not a blot; the open padlock readable on the gold. A macro's own right-click
  run by the game (`*type2`, `macrotext2`), in a fight too, and never the game's macro of its left button
  (`macro2` = `ATTRIBUTE_NOOP`); the editor's two new boxes and their prompts in each language, on one line.
- Undo and redo in the game: the two keys listed under KaLi HUD in the key bindings (`Bindings.xml`, its
  `BINDING_*` names), a folder deleted and undone, its secure button and list back, its macros running again; a
  folder's reset and its macros made anew there.
- An attribute's sources in the game: `C_Item.GetItemStats` on a worn item's link giving its stats under these names
  (its random suffix's in it, an enchantment's or a set's not, their « Autres »); the bonus armour, resistances and
  defence on gear in the armour's, the resistances' and defence's changes; a melee attack power on gear in the ranged
  one's; `AuraData.points` numbered by the spell's effects or its auras, a stacked aura's for all its stacks, or none on
  Forever (then the data's, and a level's buff unnumbered); a buffed armour's « Autres » nothing with Devotion Aura
  alone; an item's hit or critical strike a rating `GetCombatRating` counts. The probe (`/khprobe`, then `/reload`)
  keeps each aura's spell and points, each worn item's stats and the sheet's sums for this (its report's `stats`).
- Every source (2026-11-17), its guesses: an item's own armour under `RESISTANCE0_NAME` in its stats, and in the
  armour's base rather than its changes (so « Base » nothing but the race's); the agility's armour and the
  attributes' attack power in the base too; an enchantment's stats in the changes, `C_Item.GetItemStats` leaving them
  out; a talent's definition's spell one for all its ranks, its value the curve's at `activeRank`; a passive talent or
  racial not among the auras `C_UnitAuras` lists (if it is, it's named as the aura, once); `C_Item.GetWeaponEnchantInfo`
  answering on Forever for the oils and stones; an enchantment's line in the item's tooltip data with its `type` 15.
  The probe's report's `sources` keeps each worn item's item string, kind, set, armour and enchantment line, the
  weapons' enchantments for a while, the form, what the attributes give, and each talent bought with its rank,
  definition and spell, to check these.

- The second round's features (2026-11-17), to see in the game: the flash to the eye (its strength, its half
  second, over an icon and over a text); the reputations' folder with a real character's forty factions (its list's
  width at twelve to a column, the standings' colours), « Afficher comme barre d'expérience » ticked then unticked
  (`C_Reputation.SetWatchedFactionByID` with 0 is inferred to watch none), a header folded in the pane taking its
  factions out of the folder; the clock following the two boxes of the game's clock window at once
  (`timeMgrUseMilitaryTime`, `timeMgrUseLocalTime`: the names are this build's source's); a new measure started at a
  dungeon's door; an addon installed since, its data source in « Add-ons » and those already on the bar where they
  were at the first login after this.
- The review's fixes (2026-11-17), to see in the game: a fight starting with the padlock open, shut as it starts with
  nothing blocked (the macros' `SetAttribute` during `PLAYER_REGEN_DISABLED`), a macro's right-click then running,
  open again after; a folder left open, then `/reload`: no error line; « Suite » at the bar's right end with the
  text size at 20 (or many items put on the bar), its chevron and list to the eye, an element used from it, one of
  Blizzard's widgets in it, all back on the bar at size 10, « Suite » gone from it then and what stood beside it
  moved by its width (seen as a jump or not); a text changing its length (the frame rate round 100)
  moving nothing; an addon loaded on demand, its minimap button gathered; a right-click on another addon's plain
  readout, the padlock shut.

Answered by the probe's report, 2026-11-13 14:13 (build 70938): every frame below exists and is Edit Mode's
(`MainActionBar`, not `MainMenuBar`; the totem bar is system 25); the screen is 2100.5 x 1181.5 units at UI scale
0.6; `C_Reputation.GetWatchedFactionData` answers (`GetWatchedFactionInfo` is gone), `C_TooltipInfo`'s repair cost
too. FlareUI hides Blizzard's chat tab dock by parking it at -10000 and draws its own skin around the chat
(`ChatFrame1.FlareUI_Skin`, and `FlareUI_DMSkin` on the damage meter's window): the plate takes that skin, and a part
far from its frame doesn't count (the chat took the whole screen before, Ikar 14:20).

- The frames on Forever: `MainActionBar`, `MultiBar*`, `StanceBar`, `PetActionBar`, `MultiCastActionBarFrame`,
  `MicroMenuContainer`, `BagsBar`, `ChatFrame1`, `DamageMeter`, `MinimapCluster`, FlareUI's frames; their sizes in
  `UIParent` units and their Edit Mode settings.
- Does moving a system from addon code in Edit Mode keep after Save, and is anything blocked afterwards?
- Which broker objects Ikar's addons offer, and with which fields.
- The watched faction (`C_Reputation.GetWatchedFactionData` or `GetWatchedFactionInfo`), the repair cost
  (`C_TooltipInfo.GetInventoryItem().repairCost`), the honour calls.

## Not doing

- Buttons of our own in place of Blizzard's action bars (the hub's macros, Ikar 2026-11-16, are elements of the hub,
  not bars), snapping, moving the frames the plate takes (Edit Mode's and the player's), spots or pins, the threat
  window (FlareUI's own mover), a copy of Titan Panel's code (its licence forbids it: we write our own).

## The review of 2026-11-16

At Ikar's request, a review of the three addons ("I want them to be flawless"), then "Fix all", while another session
built the macros and the secure folders: the two agreed on who held which files. Every offline check passed before it:
what it found had got past the tests, mostly because the fake game answered what the game doesn't. Every fix has its
deliberate break in `tools/breaks/hud.py` or `shared.py`. Tested offline only; no in-game test run is on record yet
(`/kh test`).

- **Dragging the strip in Edit Mode raised an error.** Its box is Blizzard's template, whose own drag scripts call the
  parent's `OnDragStart`, as one of Edit Mode's systems has; the strip isn't one and doesn't move. The scripts are
  taken off. The fake's box had none of Blizzard's scripts; it has them now.
- **`/kh status` with the saved data refused** raised an error, reading the items that data would have held: it shows
  the status, which says why, which is what the command is for then. `/kh` in a fight no longer lists the commands
  under the game's refusal.
- **The info bar off.** Other addons' minimap buttons, gathered on the bar or in a folder of it, were put away out of
  reach, LibDBIcon's among them. They go back to their addons, on the map, while the bar is off, and are gathered
  again with it; one the player hid in the hub stays away. A LibDBIcon button with no object in the hub is left alone.
- **The mail on the bar keeps its place** with no mail, empty, so the items beside it stand still as mail comes and
  goes (Ikar's rule: nothing moves on a game event outside Edit Mode). In a folder's list, laid out as it opens, it is
  left out then.
- **A colour chosen with the picker** has its line in the list at once (`Shared/Dialog.lua`: a list may be worked out
  each time it opens).
- **A folded window comes back as see-through as it was**, FlareUI's skin round the chat too: they came back at full
  strength, whatever the player had set.
- **What runs every frame stops at its first error** (`ns.EveryFrame`): a fold on its way, which then stands where it
  was going, the live plate in Edit Mode, a status bar's drag. An error there came back every frame (6,000 of one on
  2026-11-13). The calendar's every-frame hook too.
- **Blizzard's day and night frame is hooked**, as the others: its scripts were set in its place.
- **A step of just 0.01 between two stretches** was a corner for the count and none for what raises one: with « Coins
  au plus » under it, nothing was found to raise and the plate wasn't drawn.
- **The speed, hidden in a fight,** is read through `ns.Plain`; an offline check fails a call the API docs mark as
  possibly secret that isn't.
- **German and Spanish** (Spain's, and Mexico's with its own words and numbers), with the shared language test in
  `KaLiHUD_Tests`; the TOC's notes and category in both. A README and a CHANGELOG in the addon's folder.
- **`hud/art/`**, Ikar's sheets, is in `.gitignore`: 13 MB of images, local unless he chooses to publish them.
- **Every label fits its room, in each language.** The dialog's label for a slider or a list is Blizzard's: 100 wide,
  two lines, and the game cuts what doesn't fit with an ellipsis, which only a player in that language sees. The
  German and Spanish written that day had five too long (« Rahmendeckkraft », « Hintergrundfarbe »,
  « Hintergrunddeckkraft », « Fortschrittsleisten », « Alejar automáticamente »). German now breaks a long word by
  hand, as Blizzard's own German does (`"Fortschritts-\nleisten"`, theirs is `"Symbol-\nabstand"`), and says
  « Transparenz », Blizzard's German word for opacity; a tooltip's title has the word whole. The options page's row to
  Edit Mode was a sentence too long for its one line in every language, on Blizzard's own list before as on the
  addon's page: it is « Plaque, marges et minicarte », as KaLi Quest's « Taille, place et apparence »; « Tous les
  réglages d'apparence » since 2026-11-20, the dialog holding the style, the borders, the windows, the progress bars
  and the info bar too. An offline check
  (`tools/kali/labels.py`, "labels:" in each runner) measures every text of the dialog and of the options page, in
  every language, with the game's own font read from a bench's art folder. **New rows keep to it:** about 13 letters a
  line for a label, a dropdown's value on one line of 195.
- **The dialog's own controls are tested.** The session set the options itself and called `ns.ApplyAll`, which says
  the HUD follows its options, not that the dialog's sliders, boxes and buttons set them: five deliberate breaks of
  the shared dialog went unseen (a change not applied, « Par défaut » leaving the values, a section that never closes,
  « Annuler les modifications » lit with nothing to cancel, a box that writes nothing). The smoke now drives them.

**Left as they are:** Blizzard's own widgets put on the bar are hidden with it when it is turned off, as the player's
own choice of place; only other addons' buttons, gathered there unasked, go back.

## The review of 2026-11-17

At Ikar's request ("a full, thorough review… focus on robustness, and the info bar usability… propose enhancement…
user research"): `review-2026-11-17.md`, beside this file, with its twelve defects (D1 to D12), each shown by a probe
on the fake game, its fifteen proposals (P1 to P15) and what players write about such addons. Then, the same day, to
its five open questions: "1. Yes, he reopen 2. Don't understand 3. You mean in the bottom bar ? Maybe a special
folder ? 4. Flash is ok, but why the folder open ? I don't see a case. 5. What is the point ? Fix all the bugs."

Fixed, each with its case in the smoke (or the saved data's tests, or the runner's own scenario) and its deliberate
breaks in `tools/breaks/hud.py` (« review D01 » to « review D12 », « review notes »: 55). Checked offline only. One
of the first 48 went unseen: other displays offered what this character hasn't, which the cases tried on unnamed items
alone, kept out for want of a name; it has its case (an item with a name the character hasn't). Reading the fixes
again found two side effects of the places that hold, corrected the same day, each with its break: the zone's name
off the map's centre once a longer one had been met, and a place left wide after a choice of the player's in an
element's menu (the clock by twelve hours, then twenty-four). And four of the folder for what doesn't fit, each
with its break too: a folder of the player's ticked to take it left the bar while it held nothing, as « Suite » does;
« Suite », another folder ticked or its own box unticked, came up on the bar empty; « Suite » reset wasn't the
folder that takes what doesn't fit again; and the folder ticked to take it, deleted, left nothing to take it.

- **D1, an error at every login while a folder is saved open.** `Folders.Setup` called `onlyOpen`, declared after
  it: a global there, nil. The hub's start stopped there, the macros' start and what's made once never run. The
  function stands before its use; `Hub.Start` runs its three steps each on its own (`ns.SafeCall`), as `Core/Main.lua`
  the pieces. The smoke's login has the folders' setup fail on purpose once its work is done, and the session ends
  with a folder open, so the runner's restart check logs in from that.
- **D2, a fight that starts with the padlock open:** The padlock in a fight, above.
- **D3, more on the bar than it is wide:** What doesn't fit on the bar, above.
- **D4, a text that gains or loses a letter moving what follows it:** Places that hold, above.
- **D5, one element failing to draw taking the bar with it:** How it stays light, above.
- **D7, an error during a drag:** Dragging is seen, above.
- **D8, a minimap button made after login:** Other addons' minimap buttons, above.
- **D9, a right-click that did nothing:** One right-click, above.
- **D10, an open folder laid out once for each member that changed:** How it stays light, above.
- **D11, what is offered to other displays:** The info bar, above.
- **D12, a saved key that isn't a name.** `DB.Open` drops an item, or a button left to its addon, whose key isn't a
  text, counted as repaired: a number there reached the code that reads names and stopped the first setup.
- **Its smaller notes:** the session's blocked actions keep their last fifty, their count going on; the errors' count
  and the time away aren't drawn again by an update that changes nothing (their colour one table each).
- **For a new player:** the runner now starts KaLi HUD as the only addon installed (no LibStub, no LibDataBroker, no
  other addon's button): a login and a short session without error, then the library arriving with an addon loaded
  later (`hud/tools/run_tests.py`'s `alone_problems`).

Not fixed, and ruled the same day, the three asked again in plain words, each with an example:

- **D6, the plate and a layout changed outside Edit Mode: no defect, by ruling.** The game applies another Edit Mode
  layout when the specialisation changes, and the options' action bars page shows or hides bars 2 to 8: the plate
  then stays drawn where the bars were until Edit Mode is opened or `/kh redraw`. Ikar 2026-11-17: "No, only in edit
  mode, I don't think the user will be happy with the new form without changing the other bara" (When it redraws,
  above). Nothing to build.
- **P3, a mark on a folder when something in it needs the player: not built.** Ikar 2026-11-17: "No need for now,
  the goal is not to have a notification system." With it goes the question of which states would count.
- **P14, a key for a macro or a folder: not built.** Ikar 2026-11-17: "No, this is not the job of the info bar."
- **The last of the review's smaller notes: a map button put away as its addon's LDB object's twin** (`Collect`'s
  `twin`; the ruling of 2026-11-14, for KaLi Recipe's). One put away so has no entry in a menu to bring it back, should
  an addon's button and its object of the same name ever do different things. No such addon was met: left as ruled.
- **The other proposals** (P1's limit on a long text, P4 to P13, P15), none built, none ruled out. Of P4 (a sign
  that an action worked): "Flash is ok, but why the folder open ? I don't see a case", so the flash alone if it's
  built.
- **A second round, about play.** Ikar, the same evening: "You spent half a day fixing issues fine, but I didn't hear
  from you any enhancement proposal, other than a glow when activating an element. Not talking about the previous 3
  that were bad ideas. This is a bit thin." The reply to the review had shown him five proposals and left ten in its
  file, none about play. Thirteen are in the review's section 5, kept to his own tests of 2026-11-16 and of this day,
  each numbered for his answer: a Shift-click that says a readout in the chat, any item counted, saved instances and
  resets, the hearthstone, a reputation for each progress bar, a new measure of the session, hit and defence against
  a boss, six readouts a notch further, and five of the first round's.
- **The second round's rulings (Ikar 2026-11-17, by number), and what was built.** Each built with its cases in the
  smoke and its deliberate breaks (« flash », « second round 6 » to « 11 », « reputations »: 37), checked offline
  only.
  - 1, a Shift-click that says a readout in the chat: no. "Not that usefull, second example is an example of
    probably useless."
  - 2, any item counted: no. "And why someone won't have them on their spell bar ?"
  - 3, saved instances and resets: no. "Unsure of the benefit."
  - 4, the hearthstone: no. "Again. Spell bar."
  - 5, a reputation for each progress bar: otherwise. "We can add a reputation folder." **Built:** one item for
    each faction the game's reputation pane lists (`UI/Hub/Infos/Reputation.lua`; `C_Reputation.GetNumFactions`,
    `GetFactionDataByIndex`), a header with no standing of its own none: its name, its standing in the game's colour
    for it, and how far into it as a percentage, nothing more at the last standing; its tooltip the count, what's
    left and the faction's own words; a click opens the pane. They stand in a folder KaLi HUD brings, « Réputation »
    (the game's word; role `reputations`, a banner, twelve to a column), last of those it makes: made for a game saved
    before it (`db.seeds.reputations`), it stands at the inner end of the bar's left side, so nothing on the bar
    moves. A faction met shows, last; one the pane no longer lists (under a header the player folded there) goes
    until it does, as an unlearnt skill does. Nothing kept. Its menu has the game's own « Afficher comme barre
    d'expérience » (`SHOW_FACTION_ON_MAINSCREEN`; `C_Reputation.SetWatchedFactionByID`, 0 for none: inferred from
    retail), which a progress bar set on the reputation shows: the choice he was offered, from the folder. The bar's
    menu lists them under their own heading.
  - 6, a new measure: yes. "Why not." **Built:** « Nouvelle mesure » in the session readout's menu
    (`Infos.NewMeasure`, `Items.NewMeasure`): the gold won and its rate, the experience gained and its rate, the
    deaths and the time shown count from then; each of their tooltips says since when (« Mesuré depuis 42 min »), the
    session's keeps the time since login beside it. Nothing saved: a login starts a session and its measure.
  - 7, hit and defence against a boss: not now. "More complexe, require to analyse what boss we have, levels and so."
  - 8, six readouts a notch further: no. "Useless, no one repair one by one, free memory more interesting": the
    performance's click still frees memory, and nothing of the six is built (forgetting a character in gold's list
    went with them).
  - 9, nothing lands on the bar unasked: "Agreed." **Built:** another addon's data source lands in the folder where
    new addons land, as its launcher and its map button do (`Hub`'s build, once `db.seeds.sources` is set); with no
    such folder, on the bar's right end as before. Those that stood on a bar where they came keep to it: at the first
    login with this rule each has its place saved, then and 2 s later for the objects that come after ours
    (`Seeds`' `pinSources`); a first install has none to keep, and is settled before any folder is made (a folder
    taking its place on the right side saves the place of all that stands there, which pinned a first install's
    data sources on the bar: found by the smoke). This replaces the ruling of 2026-11-14. Not built, as it wasn't
    put to him: the folder made only when the first thing lands in it.
  - 10, its icon, its text or both for any element: "Agreed." **Built:** « Affichage » in the menu of one of ours
    or of another addon's object, when it has an icon (`Hub.HasLook`): « Icône et texte », « Icône seule » (its
    value on hover), « Texte seul »; a launcher, which comes by its icon alone, « Icône et nom », « Icône seule »,
    « Nom seul ». Saved with its place (`db.items[name].look`; the one it comes with saves none; `DB.Open` drops one
    that isn't), one action each, undone from the bar's menu. On the bar only: in a list its folder's style
    decides, round the map its icon stands alone. The experience and the performance have no icon, so no choice: my
    example of the performance by its icon alone was wrong.
  - 11, the clock by the game's own settings: "Agreed." **Built:** « Format 24 heures » and « Afficher l'heure du
    royaume » are gone from its menu, the options page and the saved data (`DB.Open` drops them); the clock reads
    the game's two, of its clock's window (`timeMgrUseMilitaryTime`, `timeMgrUseLocalTime`), each second with the
    time. Its tooltip still gives both times; its date is still written day, month, year.
  - 12, a layout for a character and one shared as a text: later. "To be done in the future, with import/export."
  - 13, a list that shuts when one picks in it: no. "Isn't that basically the auto close option ?" It is: « Au clic,
    se referme quand on le quitte », and a press outside shuts a list opened by a click.
  - The flash (P4): "And the flash yes." **Built:** an element shown again from the bar's menu, sent into a folder
    from its own menu, a folder just made, and what an undo or a redo acted on, is lit once where it stands after
    the layout that follows (`InfoBar.Flash`): the padlock's aura, gold, fading out in half a second. In a list that
    isn't open, the folder's button is lit and the list left shut, as he asked ("why the folder open ? I don't see a
    case"): which is seen is told by the folders themselves, from the outermost in, not by asking a frame whether it
    is visible. On the player's own action alone, never on an event of the game's.
- Which question each number answered: the reply to the review listed five proposals by number (1 places that hold,
  2 folders that tell, 3 never over another, with its « +3 », 4 a sign that an action worked, 5 a key for a macro),
  then five questions without numbers (the padlock after a fight, the plate and a layout changed outside Edit Mode,
  which states need attention, new data sources on the bar or in « Add-ons », keys for macros). His "3.", "4." and
  "5." fit the proposals of those numbers word for word, and are read so; his "1." fits only the first question, the
  padlock. His "2." was then either the second proposal (folders that tell) or the second question (D6): both asked
  again, and both answered no (above). Not asked again, so not answered: whether the padlock shuts at login (it stays
  as it was left, saved). Where new data sources land was put again in the second round (9), and agreed.

## The review of 2026-11-18

Ikar: "Do a full review of the kali hud addon. In depth. Stability, solidity, maintainability." It is
`review-2026-11-18.md`, beside this file: fourteen findings (V1 to V3, R1 to R7, M1 to M4), six shown by probes on the
fake game. Then: "Refactor, as much as you think is needed. And fix all except first two." The first two are his to
do: `hud/` under version control (V1), and a run in the game (V2). While it was being done: "Link each break with
test on interest, and run only those."

**Fixed**, each with its case in a scenario (below) or in `KaLiHUD_Tests`, and its deliberate breaks (« review R1 » to
« R7 », « V3 », « M2 », « what the hub makes », « windows: typing »: 33, each naming the scenario that must catch it):

- **R3, a piece that isn't there.** `Core/Main.lua` starts the pieces, and applies a setting to them, from lists of
  names ("Plate.Start"), each looked up and run on its own; one missing is kept as an error that names it, and the
  rest go on. A piece without its start ended the list there: nothing after it started, and nothing said so.
- **R1, a frame that isn't ours refusing to be placed.** `Collect.Place`, `Hide` and `GiveBack`, and
  `Natives.PlaceOnBar` and `Place`, each do their work under a guard. A frame that raises an error is given back as
  far as it lets itself be, takes no place in the hub for the rest of the session (`refused`), and the hub is laid
  out again without it. Its error took the whole bar's layout with it.
- **R2, an action that fails half way** (`History.Do`, and `History.Attempt` for what is no step to undo): what it
  had changed in the saved data is put back from the copy taken before it, each module told and the hub drawn again;
  its error is kept with the stack taken where it failed; nothing is raised again to who asked, who gets nothing
  back.
- **R4, the handlers.** `ns.Guarded(fn)`, in the shared core beside `ns.EveryFrame`: a handler the game runs on the
  player's doing, under the guard, nothing made at each call. Every script, hook, registry callback, menu entry and
  popup answer of KaLi HUD's own files is one, or does nothing but guarded calls. The runner checks it: the fake game
  records every function it is handed (`F.handlers`), and one of KaLi HUD's own files' that isn't a guarded call
  from end to end fails the run (`handlers:`). Left as they are: the shared dialog's, page's and report's own
  handlers, the family's, most of which guard what they call.
- **R5, what's made once.** Each of `Seeds.Run`'s seven steps is made whole or not at all, on its own
  (`History.Attempt`): one that fails leaves nothing of itself, its marks as they were, and is tried at the next
  login; those after it are made all the same. The folder for what doesn't fit, the same; one that failed isn't
  tried again that session. A step's mark is asked once, by `once` in `Seeds.Run`: each step also asked its own at
  its top, and the older break that takes the reputations' away changed nothing any more (found by the linking
  below, 2026-11-19); the steps' own are gone and that break takes `once` away.
- **R6, a folder's key.** `DB.Open` drops a folder, a macro or a separator whose key isn't its kind's id (`DB.IDS`,
  the prefix and a number), counted as repaired.
- **R7, a twin with the info bar off.** A button put away as its addon's object's twin is kept (`twins`) and goes
  back on the map while the hub shows that object nowhere, as LibDBIcon's do (one rule for both, `awayOrBack`); one
  taken as a button of its own whose addon makes its object later is given back first, then put away as the twin.
  The ruling of 2026-11-14 stands: while the hub shows the object, the button is away.
- **V3, a repair said.** The last load that put something right is kept (`KaLiHUDDevDB.lastRepair`: when, how many,
  the version); `/kh status` and the bug report say how many values this login repaired, and the last time.
- **The smaller notes:** typing unfolds the folded chat from the box of any window docked with it (the game's chat
  style « messagerie instantanée »; to see in game); the status names an element that failed to draw; a frame the
  game protects waits for a fight's end before it hears the mouse again (`StatusBars`' `hearAgain`).

**Refactored**, as much as I judged was needed and no more:

- **The saved places have one owner (M2).** `db.items` is written by `UI/Hub/Hub.lua` alone: `Hub.Saved`,
  `Hub.EachSaved` to read, `Hub.PlaceAt`, `Hub.Unplace`, `Hub.OutOfFolder`, `Hub.Write` to change. The eighteen
  direct writes in five other files go through them. The runner fails the table named anywhere else but there and
  in `Core/DB.lua` (`places:`).
- **What the hub makes has one description (M4).** `Hub.Made(kind)` gives a kind's ids, their list in the order
  made, the next free one and whether a name is one; `Folders`, `Macros` and `Separators` each had the same forty
  lines for it. With it `Hub.CleanName` and `Hub.IsGlyph`, each written two or three times before.
- **The tests can be run by the part (M1).** `hud/tools/run_tests.py --only <part>`: `static`, `tests`, `smoke`,
  `alone`, `scenarios`, or a scenario's name. A scenario (`hud/tools/lua/scenarios/`) is a short session from a game
  started for it alone, about a third of a second each: this review's cases are eight of them. The smoke's session
  stays one file, but each of its blocks now passes alone (`--only blocks` tries them; two leaned on an earlier one
  and were made to stand, three are the session's own start and say so after their `do`: never left out), and
  `--at <what a check says>` runs the block that holds that check with what stands between the blocks: 5 to 8
  seconds against 22.
- **Each break is linked to its test (Ikar: "Link each break with test on interest, and run only those").**
  `tools/breaks.py` runs a break against the part that must catch it, and in the smoke the one block: a break may
  name its own ("test:<part>"), else its link is found once (`--link`, which tries the parts in turn and keeps what
  it finds in `tools/breaks/links/`), and the block a link names is tried alone on the code as it is before a
  catch there counts. A break with no link runs the whole runner, as all did.
  The older breaks got theirs on 2026-11-19 (Ikar: "all the 500 breaks need also to be linked, I expected it was
  done"), so none is left without: of the 367 in `tools/breaks/hud.py`, 46 name their own test and 321 have a link,
  270 to one block of the smoke, 36 to the whole smoke (the break gives a Lua error, or its check isn't one the
  session's source spells out), 13 to the unit tests, one to the fresh install (`alone`) and one to the static
  checks. None went uncaught. A block that always-run lines after it stand on must say so after its `do`: one
  added that day without the mark (it held the drop of a drag) left nothing passing alone, and every new link fell
  back on the whole smoke until it was marked.

**Not done, by choice:** the long functions (`Folders.Layout`, the editor's `build`, `DB.Open`) are as they were:
they are read top to bottom, they are what the breaks patch by their exact text, and none was in a finding's way.
The smoke isn't rewritten as scenarios: its blocks stand alone now, which is what running a break needed. The
coupling between the info bar's files is as it was but for the saved places.

## The review of 2026-11-19

Ikar: "Do a full, in depth review of the addon, especially it menu, settings export, preset. The data validity is
paramount. User should never loose it settings. All reset, écrasement and replacement should be deliberate decision
(confirmation popup, etc)." The rule, from that day: **what resets, replaces or drops something of the player's asks
first** (`ns.Ask`, `Core/Init.lua`: the game's yes and no, Escape the no), and nothing kept for the player goes
without his word.

Read for it: the saved file's load, repair and writing (`Core/DB.lua`, `Core/Main.lua`), the sets (`Core/Sets.lua`,
`UI/SetWindow.lua`), the options' pages and Edit Mode's dialog (`UI/Options.lua`, `UI/EditPanel.lua`, the shared
`Page.lua` and `Dialog.lua`), the undo (`UI/Hub/History.lua`), the bar's menus (`UI/Hub/Menus.lua`, `Folders.lua`,
`Macros.lua`, `Seeds.lua`), the macro editor, the commands.

**Found and fixed**, each with its case (scenario `sets`, or the smoke) and its breaks (« asked first: », 10;
« kept whole: », 10):

- **The options page's « Réinitialiser » asked nothing.** One click put the eleven options of « Comportement et
  sons » back, with no way back. It asks, naming the page.
- **« Propres à ce personnage » unticked asked nothing, and what it kept didn't last.** The account's settings
  replaced all of the character's at once; its own were kept as « Sauvegarde », of which the oldest goes once there
  are three: three sets applied later, they were gone for good, with no word. The box asks first, as the game does
  for its key bindings, staying ticked until the answer; the character's own are kept as a preset of the player's
  (`keep`, past the ten if need be), which only he deletes. Settings found under a character's name that nothing
  reads (a file from elsewhere) are kept the same way when it takes its own anew, where they were dropped.
- **A folder's, a macro's and an element's « Réinitialiser » asked nothing.** A folder's puts back its contents and
  the commands of the macros made for it, a macro's its commands, right-click, tooltip and descriptions: what the
  player wrote. Each asks, the question saying what comes back (its tooltip's words). Still one step to undo after.
  The place's own reset (« Position ») is a move, and asks nothing.
- **The macro editor dropped what was typed.** Escape, its X, another macro opened in it, a note's second click: a
  note of a thousand letters gone without a word. It asks now (« … fermé sans être enregistré. Enregistrer ce que
  vous avez tapé ? »); yes saves it (in a fight, when nothing is saved, the editor opens again on it); the macro
  opened again before the answer takes up what was typed. « Annuler » still drops it: its word. No Escape on that
  question: the key that shut the editor, pressed once more, would be the no.
- **The editor forgot its macro when the whole interface hid** (Alt+Z, a cinematic: the game tells a frame it hides
  though it wasn't shut): back, « Sauver » saved nothing. As the card kept open earlier that day.
- **A set that failed half way was put back in part.** The undo's own putting back covers the five tables its
  actions change; `buttonsLeft`, `statusPlaces` and `seeds` stayed as the failed set left them. `Sets.Apply` puts
  those back itself.
- **How things stand went into a set.** The chat and the meter folded, the padlock open: a set from another player
  folded the chat and opened the padlock of whoever applied it. Neither kept in a set nor taken from one (`STATE`);
  the account's copy keeps them as a character takes its own.
- **A set's date, owner and marks weren't checked at load.** A date that was a text stopped the set's window from
  opening (the game's `date` raises an error); a mark that wasn't `true` listed a set as a backup and counted it as
  a preset. Repaired at load, the set kept.
- **A set from a text says what it may hold.** A macro's commands run on a click, whatever they are (`/run …`): a
  set imported is marked (`imported`), and its window says, in words, that its macros' commands run when clicked and
  to take its info bar only from someone trusted. Brought up to date, it is the player's and says no more.

**Found sound**, nothing changed: a file from a newer version, or one that can't be read, is left as it is and the
addon does nothing; a character's own settings go back under its name before the file is written, and a file written
without that is read as it should have been; an import adds a set and applies nothing; a text that isn't a set, one
cut and one from a newer version are told apart, and what a text holds is repaired as the file's own before it
reaches the HUD; « Mettre à jour » and « Supprimer » ask; applying is refused in a fight and keeps the settings as
they were; a folder's and a macro's deletion ask; a style that would replace a changed value asks; the dialog's
« Par défaut » asks; only `Core/Main.lua` writes the file's shape at logout.

**For Ikar to rule** (asked that day):

1. Edit Mode's sections' own « Par défaut » ask nothing, by his word of 2026-11-16 ("add 2 button per section,
   cancel and default, no warning"); the section's « Annuler » puts it back until Edit Mode is left. Left as ruled.
2. « Partager » puts the notes' text and the macros' commands in the text, with the rest of the info bar. Said
   nowhere.
3. Three « Sauvegarde » are kept, the oldest going at the fourth set applied.

**Noted, not changed:** two presets may bear the same name (none is replaced); a character deleted from the account
keeps its own settings in « Reprendre des réglages », with nothing to remove them by; a set applied while a macro's
editor holds something unsaved drops it with the macro, if the set takes the info bar.

Nothing of it seen in game.

**Checked offline only**, as all before it.

## The review of 2026-11-20

Ikar: "Do a full review of the characteristic and it calculation, take your time, scrap what needed to confirm all
the use cases." Read for it: `UI/Hub/Infos/Stats.lua` whole, against this build's character sheet (Camelot's
`PaperDollFrame.lua`, `PaperDollFrameStats.lua`, `SkillsFrame.lua`, `PaperDollFrameConstants.lua`), its strings
(BlizzardInterfaceResources' GlobalStrings, 1.60.1), its data (DB2 1.60.1.70790: `SpellEffect`'s every aura kind and
the spells of each, `ItemSparse`'s item stats, `TraitDefinition`), its API docs (`Blizzard_APIDocumentationGenerated`),
and its rules as the original game's server has them, with TrinityCore's code for the modern numbering and masks
(`SpellAuraDefines.h`, `SpellAuraEffects.cpp`).

**Found and fixed**, each with its smoke check (« The full review of 2026-11-20 ») and its break (« review: »):

- **A share of the attributes went to strength.** Aura 137's attributes are a mask in its second misc, as the modern
  server reads it (TrinityCore's `HandleModTotalPercentStat`: `GetMiscValueB() & 1 << i`, 0 all); the generator took
  the first, 0 on eighteen spells of other attributes: Heart of the Wild, Divine Intellect, Mental Strength, Ancestral
  Knowledge (intellect), Lightning Reflexes (agility), Demonic Embrace (stamina), Vitality, Tree of Life's spirit.
  They were named on strength and missing on their own. `make_effects.py` writes the mask.
- **A percent buff on an attribute left a false base and « Autres ».** The original server multiplies the bonus alone
  by a share of the whole (TrinityCore's `UpdateStatBuffMod`), and the base
  then holds the share's part of it: Blessing of Kings on a strength of 100 with an item's +10 showed « Base 110 » and
  « Autres -10 ». Which way this build splits it isn't known: the card takes the reading that leaves less unexplained,
  « Base 100 » either way. A share of the base (80: Sayge's fortunes) raises the items' own stats too (the
  enchantments' and the buffs' added after): counted.
- **A rating not had yet was one percent a point.** An item tried with 14 points of critical strike said +14 %, and
  this build's items carry hit and critical strike ratings (184 and 522 of them). It is what the game's own call makes
  of it at the level (`GetCombatRatingBonusForCombatRatingValue`), a set's next bonus too; a rating the character has
  none of counts for nothing now (an item's critical strike not on the spells); none at all said with the question
  mark, the game giving nothing.
- **The speed.** Two raises of a kind both counted; a mount's and a swim's not read. The original server's rule:
  of each kind of raise for how the character moves the strongest alone, those that
  stack multiplied, the better of those and the non-stacking one, the strongest slow; mounted (32, 130, 172) and
  swimming (58) their own kinds, running 31, 129, 171; the others said « non cumulé »; what the named ones leave of the
  speed, as a share of what they come to, « Autres » (a mount whose speed the game keeps on a hidden aura); the
  swimming from its own base, 4.72 yards a second. No sum over changes that multiply (the speed's, the haste's).
- **The dodge, the parry and the block named the defence above the level's most alone.** The original server adds its
  share either way to the value it shows, 0.04 % a point: at 113 / 115, « Défense -0,08 % ».
  None on a value at 0 (no shield, no parry); their « par point » line says « de part et d'autre de 115 », not
  « au-delà » (`STAT_RATIO_AROUND`). This build's sheet code holds the same rule for the blows taken
  (`GetEnemyChanceToMiss`, `GetEnemyCritChance`, which the sheet doesn't call), and the defence's own card follows it:
  the previous day's answer that the build doesn't state it was wrong.
- **The weapons' critical strike didn't name the weapon skill**, which the original server adds to the value shown
  against the level's most, either way, as Forever's Skills tab says
  (`GetCriticalHitChance`): « Compétence (Épées) 0,4 % » for 125 of 115.
- **The spells' power and healing**: a share of an attribute (174, 175: the priest's Spiritual Guidance, 1 to 8 % of
  the spirit for the damage, 5 to 25 % for the healing) and the orc's Blood Fury, a share of the whole (317), were left
  to « Autres ». Named, the share's worth worked out, and what's left of the whole without it. The schools are said
  after a flat change alone (a share has none: « Fureur sanguinaire () »).
- **The attack power from a share of an attribute (Ikar 2026-11-21: "dexteriter mental seem not to be shown in attack
  power", "it is a atalent, chaman talent").** Forever's shaman talent Mental Dexterity (trait 134216, spell 415140:
  50, 100, 150 % of the intellect) is aura 598, which the data left out; so are the hunter's Careful Aim (1223984, of
  the intellect) and Cat Form's passive (3025, 100 % of the agility). 598 gives the melee and ranged attack power both
  (Careful Aim is a ranged one's, Cat Form a melee one's). Named on both, as points: the share of the attribute now.
  Not of the strength or the agility, which the attributes' own part may hold (`GetAttackPowerForStat`: whether the
  game counts Cat Form's agility there isn't known; it stays in « Autres » if not). Where the game counts it isn't
  known either: the original server in the base (TrinityCore's `UpdateAttackPowerAndDamage`), an aura's points in the
  bonus. In the base where that leaves the less unexplained and the base's own row holds it: among what the value
  stands on then, « Base » less it. Looked for with nothing in the bonus too, for that. Seen in game the same day
  (Ikar's shaman): in the base, « Base 8, Force 112, Dextérité mentale 60 », the gear's +6, 186, nothing left.
  Wrong, found at level 24 (Ikar: "puissance d' ataque, base = 5, where do this come from ?"): « Base » was what the
  rest left, so any figure added up. The game's base, 195, is 2 x 24 - 20 = 28, Force 122 and 45, the intellect's
  100 %; the card had 150 % (68), the talent's rank 3 in the data (50, 100, 150 by rank; its spell's own 100). So
  (Ikar: "you know the base, yo uyou could have known the conflict. The base shoudl now always match. And yo ucould
  add a addon mistake: and show the difference, to be reported, in red"): « Base » is now the level's and the class's
  part (`LEVEL_AP`, the original server's formula: melee 3 a level less 20 for warriors and paladins, 2 less 20 for
  rogues, hunters and shamans, -20 for druids, -10 for mages, priests and warlocks; ranged 2 a level less 10 for
  hunters, 1 less 10 for rogues and warriors, -10 for the others); a share of an attribute is in the base; and what
  the card can't account for of the game's base is a row « Erreur de l'addon » in red, with the difference, its foot
  saying it's KaLi HUD's mistake, to be reported. The bonus's rest stays « Autres » (a buff the card can't read isn't
  its mistake). The old reading by what leaves the less unexplained is gone.
- **Each base named after where it comes from (Ikar 2026-11-21, of « Base et autres 1,7 » on the critical strike:
  "each base need to be explained", "lvl can be a source on it own, like intel and so").** No row is « Base » any
  more: each is named as the game's unit tooltip names a character, its strings (`UNIT_LEVEL_TEMPLATE`,
  `UNIT_TYPE_LEVEL_TEMPLATE`, `SKILL_LEVEL`) and `UnitClass`, `UnitRace` its names: the class's own for a chance
  (critical strike, dodge, parry, block: « Chaman 1,7 % », the shaman's own critical strike, the same as the
  original server's 1.7) and for an energy or a rage; the class's at its level for health and mana (« Chaman niveau
  24 »); the race's and the class's at its level for an attribute (« Orc Chaman niveau 24 »); the defence's skill as
  trained (« Niveau de compétence »); the attack power's level, with how (« Niveau 24 (2 x 24 - 20) »), or the class
  where the level adds nothing (« Mage (- 10) »). Drawn in white as an attribute's part is, a source of the value.
  Where the card names the rest of a value that has a base (a chance, health, mana), the name is the card's reading:
  a kind the data had left out would land in it, as it did in « Base et autres ». « Base » stays only where the
  class can't be read. Same day, the ranged attack power's « Erreur de l'addon -35 » (Ikar: "Why error on distance
  power ?"): Forever gives a class that shoots no ranged weapon none at all, not the original server's agility less
  10: the probe's shaman had 0 with 37 agility, its agility giving none (`GetRangedAttackPowerForStat`), and Mental
  Dexterity's 40 not in it either. `LEVEL_AP`'s ranged part is 0 for paladins, shamans, druids, mages, priests and
  warlocks (the shaman's seen; the others taken alike, the classes `RANGED_CLASS` leaves out), and a share of an
  attribute (598) counts on the ranged attack power of `RANGED_CLASS` alone.
- **A base by what makes it (Ikar 2026-11-21: "why not separate race and class ? Why some chaman give intel 25,
  spirit 40 etc ? what is the logic from 24 to 40 ? same for everything").** What Forever's data holds of it,
  looked for among its tables (wago.tools, this build): `PlayerExpectedStat`, by class and level, the base mana,
  the health a point of stamina gives, the critical strike a point of agility and of intellect gives (the game's
  `GetCritChanceFromStat` the same); `RaceStat` one field, 0 for every race. No table of the attributes or of the
  health by level: the server sends their sum (`UnitStat`'s base). Each level's gains are a table, not a formula:
  a shaman's mana 55, 61, 68, 91, 100... (a priest's 140 at 4, 137 at 5). So: an attribute's base is the race's own
  at level 1, what the class adds then (`RACE_START`, `CLASS_START`: the original game's, as the classic guides
  give them, an orc warrior's 26 17 24 17 23 at 1; not in Forever's data, so not tested there), none where it adds
  nothing, and what the levels since have given, the rest of the game's figure (« Orc 23 », « Chaman 2 »,
  « Niveau 24 15 » of spirit); the mana's, the class's at level 1 and what the levels since add, Forever's table
  (`BASE_MANA`, make_effects.py), what the game's figure leaves of it « Autres » (a source not named, or the table
  not Forever's at your level). The health stays one row, the class's at its level, no table of it being in the
  game's data; a chance stays the class's own (a class's base critical strike doesn't grow: the level changes what
  a point of agility gives, the agility's row). A race the table doesn't know (none of the eight) has the one row,
  « Orc Chaman niveau 24 ».
- **The tank's figures and the white hits' ceiling (Ikar 2026-11-21, of the review's proposals: "go for the glancing
  and crushing, tank figure").** The defence's levels, I to IV, say what the enemy's blows come to against the
  character: avoided or blocked (its misses, 5 % and 0.04 % more a point of the defence past its weapon skill, with the
  sheet's dodge, parry and block), and where its skill is 15 or more past the defence's most (three levels above, or
  fewer with the skill short), its crushing blows (2 % a point of it less 15, 15 % at three, at 150 % of the damage), as
  many as one roll leaves them after the misses, dodges, parries, blocks and critical strikes, and the threshold that
  leaves them none: avoided or blocked, all the critical strikes leave. The sums are this build's own, in its sheet's
  code though the sheet never calls them (`GetEnemyChanceToMiss`, `GetEnemyCritChance`, `GetEnemyCrushingBlowChance`,
  with an attacker-level table, `AddDefenseChanceTable`, it never draws), and the original server's the same; what a
  level above takes of the dodge, parry and block, 0.2 % a level, is the original server's alone, the sheet giving them
  against an enemy of the character's level: marked (`STAT_WHY_AVOID_LEVEL`). The line's numeral stays the critical
  strike's. The critical strike's card, where the line shows the melee's, says each level's glancing blows by the
  game's own calls at its defence (`GetGlancingBlowChance`, `GetGlancingBlowPenalty`, the main hand's skill when given
  none) and the white hits' ceiling: 100 % less the misses the hit leaves (two weapons 19 % more), the dodges the
  expertise leaves and the glancing blows, plus what an enemy above takes of the sheet's critical strike (which holds
  the weapon skill's share against the level's most already): 0.2 % a level by the Skills tab, 0.6 % against a raid
  boss, and by the original server that share back and 0.2 % a point of its defence past the skill, 3 % at 300 (a
  first sum counted the skill's share twice, 0.4 % at 125 of 115, caught reading the crit's sources): with the hit's two figures,
  both, marked, reached at the higher (`STAT_WHY_WHITE_CAP`, which names magey's 1.8 % more on the auras' critical
  strikes); from behind; the techniques have none. No numeral: a ceiling isn't a goal, its « Comment » says so
  (`STAT_TIERS_NONE`). A tier's row can now be a figure alone (`fact`), neither reached nor missing. Stats.lua's main
  chunk is at Lua's 200 locals: the enemy's 5 % of critical strikes went into the new `ENEMY` table.
- **The stats panel against outside sources and other addons (Ikar 2026-11-21: "do a full review of the stats panel,
  cross check with external sources, see what other addon show and offer. Take all your time").** Read: the original
  server's rules (the miss, dodge, parry, block, glancing, crushing and critical strike
  sums, the health regeneration and block value), magey's Classic measures (the attack table, the critical
  strike's suppression), Marrow's compendium, the Warcraft Wiki's attack table (today's game's: not taken), the
  game's own Skills tab (`Camelot/SkillsFrame.lua`) and the stats addons of Forever and the Classics (ForeverStats,
  Forever Extended Character Stats, CharacterStats, Stats Log, Forever Class Live Stats, Foresight, SinStats, Pawn;
  Extended Character Stats' code; the original server's own table of attributes by race, class and level).
  Agreed with them: the attack power's level parts, the race's and the
  class's starting attributes for 32 of the 40 pairs (an undead mage's the table's own slip, its intellect and spirit
  swapped at level 1 alone), the defence's 0.04 % a point either way, the 440 of defence that takes a raid boss's critical
  strikes away at 60, a raid boss's dodge (6.5 %) and parry (14 % by the original server and Blizzard's word, 16.5 %
  by the game's texts: both, as before), the weapons' 8 % or 9 % against it and the two weapons' 19 % more, the
  spells' 4, 5, 6 and 17 % level by level. Fixed: the human's spirit and the gnome's intellect at level 1, 20 and 23 as
  the original server's table has them (the gnome's for all four of its classes), not the guides' 21 and 24, which
  hold their racials' share, a source the card names on its own (the human's 10 % of spirit in this build's data, the
  gnome's now of mana); the spells' miss that no hit takes away, 1 % on the original server
  ("Pre-WotLK: unavoidable spell miss is at least 1%"): each level's spell row says both figures, 3 % or 4 % up to
  16 % or 17 %, marked, reached at the higher (`STAT_WHY_SPELL_FLOOR`); the spells' power gives each school's figure
  where it isn't the least, as the game's own sheet lists them (`CharacterSpellBonusDamage_OnEnter`; ForeverStats
  does too), and a warlock's pet's share of it (the sheet's `WARLOCK_PET_BONUS`: 17 % to its attack power and 10 % to
  its spells', of the shadow's or the fire's, the higher), the card having had neither; a weapon's damage names its
  skill after its speed, as the sheet's tooltip adds it (`PaperDollFrame_AddWeaponSkillLine`, « Épées : 120 (5)/150 »);
  a weapon skill's tooltip in the Skills folder says what the Skills tab says of it (`AddWeaponSkillRows`): the
  chances against an enemy of the character's level and against a raid boss, level 63 whatever the character's, and
  that boss's glancing blows by the game's own calls (`GetGlancingBlowChance`, `GetGlancingBlowPenalty`), none of
  which the folder had. Still open, put to Ikar: what a weapon skill short of its most costs, 0.04 % a point by the
  Skills tab (which the card follows) and 0.1 % to 0.6 % by the original server, magey's measures and the other
  addons (ten points short against a raid boss: 0.4 %, against 4 % to 6 %); a raid boss's suppression of the critical
  strike (0.6 % by the Skills tab, 3 % by the original server, 4.8 % by magey's measures with some from auras); the
  health's regeneration sitting (33 % more by the game's text, 50 % by the original server: `/khprobe regen`, read
  standing then sitting, tells); the block value (the original server's 1 less than the sheet's strength / 20).
- **The full review of the attributes' logic (Ikar 2026-11-21: "do a full review of al lthe stat related logic. Take
  your time").** Every value read against Camelot's sheet code (its calls, its sums, its texts, its colours: the
  same), each kind of aura against the original server's sums, the would-be figures against the tally's.
  Found and fixed: 133, the health by a share, is a share of the whole (TOTAL_PCT): it had been one not worked out,
  and every tauren's health card (Endurance, 5 %) had lost its base; the armour's shares had been none worked out,
  101 now one of the whole, 142 and 466 shares of the items' own armour (`ofItems`, the original server's sum: the items'
  own by their shares, then the agility's and the flat changes, the whole by 101's), what each comes to said (a
  bear's 360 % of the items' 300, +1 080), and what an item tried would give beside them raised by them (a chest of
  150 more armour, 690 in bear form, had been said 150); a resistance's 101 the same; a value whose base is 0 had a
  « Base 0 » row (a shaman's ranged attack power, the bracers' alone); what an item tried would give a value whose
  base holds a share of an attribute (Mental Dexterity's, `levelPart`) had been short by that share, counted in its
  base and its changes both; the mana's regeneration had been held against nothing: now against the game's out of
  casting, « Autres » for what's left; the health's regeneration whole not rounded, what a source's rounding leaves
  being no « Autres »; a loop that did nothing, gone. Checked and right: the attack power's level parts (the
  original server's, a druid's forms by their auras), the stamina's and the intellect's first 20 points, the
  critical strike's weapon skill, the defence's share, the talents' words, the points by level, the sets, the
  enchantments, the speed's strongest of a kind. Still open, not settled by the game's data: the race's and the
  class's starting attributes (the original game's, the level's part the rest), the class's own chances and the
  health's base (what the named sources leave), whether the game's base of an attribute holds a share of it (the
  reading that leaves the less unexplained), the ranged attack power of the classes other than the shaman (0, taken
  alike), whether the game's health regeneration whole is the standing one (`/khprobe regen`, read standing then
  sitting, tells), and 83 on the armour (the base's points, which the original server raises by 142's shares too:
  added flat here, no spell of this build seen with both).
- **The health's regeneration, a value of its own (Ikar 2026-11-21: "health regen ?").** The sheet has none: only its
  spirit tooltip says what the spirit gives and what the whole is. Now one, as the mana's: « Régénération des points
  de vie », in 5 s in a fight, out of one in brackets (`GetHealthRegen`, a second's, x 5 as the sheet's tooltip);
  its sources the spirit's part as the sheet takes it, standing (`GetHealthRegenFromSpirit` x 0.75: whether the game's
  whole is the standing one isn't known, « Autres » would say so), items' « health every 5 s », 161 auras (Demon
  Skin and Armor, Troll's Blood elixirs) and 88's share of it out of a fight (Pure Water, Rage, Drain Life's
  -100 %, the troll's Regeneration +20 %); no base, the spirit's part being the class's and level's as the game
  works it out. 116 (the share kept in a fight) and 84 (eating) left out. Before the mana's in a new folder; an
  attributes' folder made before gets it just before the mana's (`db.seeds.healthRegen`), nothing else moving.
- **The talents' values by rank, tested in game (Ikar 2026-11-21: "review all talent, all similar assumption, can't you
  test them ?").** By hand first: of the 66 talents with values by rank, most have their spell's own figure as their
  most rank's, as the data's rule would have it; 15 don't (Mental Dexterity's 100 at rank 2 of 3, Lightning Reflexes'
  5 among 2, 4, 6, Champion of the Light's 100 among 12 to 60...), so which the game applies can't be told from the
  data. The test: `/khprobe talents` reads, for every talent of the class's trees, the game's own tooltip at each rank
  (`C_TooltipInfo.GetTraitEntry`, the talent frame's), the node's ranks (active, purchased, increased) and a learned
  one's aura points where the game shows it; `hud/tools/check_talents.py` then checks each value the HUD has for each
  rank is a figure the game's tooltip states. One class a run. Ikar's shaman, the same day: every learned talent's
  values the game's words but Mental Dexterity's, whose words say 33, 66 and 100 % (rank 3 of 3 bought, none added),
  the data 50, 100 and 150; the game counts the words' (its base to the point). Talents not learned had no words
  (« Passive » alone: their text not loaded), so nothing to check them by. Hence, on the card, each learned talent's
  value held against the game's own words at its rank (`C_TooltipInfo.GetTraitEntry`, read with the talents): kept
  where they state it; else, a talent of one effect whose words state one figure, that figure; else the mark, the foot
  saying the game doesn't give what the rank brings, rather than a figure it doesn't give. Words not loaded yet: the
  data's, asked again next time.
- **Every kind the data left out (Ikar 2026-11-21: "review all others").** Each aura kind `make_effects.py` didn't keep,
  counted on the spells the cards read as sources (talents, passives, gear, sets, enchantments, consumables) and then
  on every spell of the kind. Four change a value a card shows, now kept and named:
  - 9, the melee attack speed by a share: Juju Flurry (3 %), the paladin's Seal of the Crusader (40 %, beside its
    attack power), speed buffs and slows;
  - 557, the ranged one: the quivers' and ammo pouches' « Hâte » (10 to 15 %), under their item;
  - 178, a power's most by a share, its misc the power's kind: the gnome's Expansive Mind (5 % of the mana, the rage
    or the energy), on the power shown alone;
  - 466, the armour from items by a share: the bear's and moonkin's forms and Toughness have it beside a 142 of the
    same share, which was named already, so it's kept only where a spell has no 142 (two debuffs, « Brèche
    furieuse », « Condamnation à mort »): else the forms' 180 % would show twice.
  Left out: spells' modifiers (107, 108), procs (42), the dummy (4), damage done or taken and against a creature
  kind (79, 87, 59, 102, 131, 168, 180), the shield's block value (272, 274: shown without a card of sources), the
  health's and other powers' regeneration (84, 161, 85 off mana, 110), threat, crowd control, transforms. 593, sets'
  « Expertise augmentée », lowers the chance to be dodged and parried: whether the game's expertise counts it isn't
  known, so it isn't named; one look at the expertise card with such an item on would tell.
- **The expertise had no sources**: its aura (240: a rogue's Weapon Expertise, a flask), its rating (the tier 1 tank
  sets' four pieces, 12 points; `RATINGS` holds CR 24 now) and the items' (8). The parry of an enemy of the
  character's level, 5 % (`CR_EXPERTISE_TOOLTIP`'s « créatures de même niveau »), is among its thresholds.
- **The armour penetration had no sources**: the armour ignored (123 on the armour: Bonereaver's Edge, 700). The
  spells' penetration takes 123 on a magic school alone.
- **The hit against an enemy one or two levels above was the sheet's table's alone** (5.2 and 5.4 %, a table its
  code doesn't read). The original server's gives 5.5 and 6 % (0.1 % a
  point of a creature's defence above the weapon skill, up to 10), as the sheet's own dodge table does (5.5, 6): both,
  reached at the higher, the question said (`STAT_WHY_NEAR_HIT`).
- **An attribute's « Autres » kept open was not checked against what would be**: a check on the strength's card now
  says it stays once, as it is.
- **The energy and the rage had no sources** (a rogue's Vigor, +10 energy): the power shown's own (aura 35's misc its
  kind), the items' mana for mana alone.
- **The armour's and the resistances' base by points** (83) unread.
- Small figures below a tenth of a percent are written to two decimals (« -0,08 % », not « -0,1 % »).

**Checked and right**: each value read as the sheet reads it (`PAPERDOLL_STATCATEGORIES`, in its order); the
attributes' colours and base; a weapon's damage and its tooltip's base; the attack power and the one taken from the
spell power; the hit, critical strike and haste the best of three; the expertise's text, the ranged one's as the
sheet's; defence's most five a level; the block whole as the sheet's; the armour from its whole; a resistance's
average (0.75 x points / (5 x level)) and its 75 %; the spell penetration a point; the health from the stamina (20,
then the game's per point), the mana from the intellect (20, then 15), the spirit's health standing (0.75), the
agility's armour (2 a point), the strength's block value (one in 20); the raid boss's figures as the game's texts
give them (8 or 9 %, 17 %, 27 or 28 %, 6.5 %, 14 or 16.5 %, 440 defence: 315 + 5 / 0.04); the points that grow with
the level as the server's (`fixedPoints`); the skills' lines of the weapons as the Skills tab's.

**Left open**:

1. Which way this build splits a percent buff between an attribute's base and its bonus: to see in game, with Kings,
   Spirit of Zandalar or a human's spirit (The Human Spirit, 10 %).
2. The armour ignored by a share (280: Serrated Blades, Hack and Slash, two talents): whether
   `GetArmorPenetration` holds it isn't known; not named.
3. The mana regeneration's card names the spirit's part out of casting beside its main figure, while casting.
4. A mount's speed on an aura the game hides can't be named: « Autres ».

Nothing of it seen in game. **Checked offline only**, as all before it.

## The languages, 2026-11-21

Ikar: "Review the transition in detail, make sure everything make sense, clear, in each language. Take your time."
The review of the three addons' strings, every key side by side in French, English, German and Spanish:
`review-2026-11-21-languages.md`, beside this file, with each finding before and after. Then, on its questions: "About
icons, yes. As much as possible. And make the translation correct in each language, with each language it own rules.
Also, each language in it own file."

- **One language a file.** `Core/Locale.lua` keeps the machinery and loads first: the client's language, the mouse
  marks (`ns.LEFT_CLICK`, `ns.RIGHT_CLICK`), `ns.STRINGS`, `ns.StringsFor`, `ns.L`, `ns.G`, `ns.One`, the sort's folding,
  and `ns.Typeset`. Each language is `Locale/frFR.lua`, `enUS.lua`, `deDE.lua`, `esES.lua` and `esMX.lua`, in the TOC
  right after it; Mexican Spanish still takes Castilian's but for its own words. `ns.L` reads the language when a string
  is read, not when the file loads (the languages' files come after it; a test can now switch `ns.LOCALE`). The key
  bindings' names moved by their function (`UI/Hub/History.lua`), set once the languages have loaded. The split changed
  no string: every key of every language compared with the one file before it.
- **Each language's own rules,** as its file states them at its foot, put in as its strings load so the files keep plain
  spaces and straight apostrophes, easy to read and to write (`ns.Typeset`):
  - French: a no-break space before « : ; ? ! » and », after «, and between a figure and %, as the game's French prints
    them (1,858 « : » after a no-break space in its strings, 175 after a plain one); its apostrophe ’ (5,054 to 1,819);
    quotes « ». A line of a tooltip no longer starts with « : » or « ? ».
  - English: quotes “ ”; no space before % (« 100% »); American spelling, as the game's.
  - German: quotes „ “ (Duden's; the game's own German writes straight ones); a no-break space before %; Ihr, Euch,
    Euer to the player, as the game; a whole sentence after a colon starts with a capital.
  - Spanish: quotes « » (the RAE's first choice; the game's Spanish writes straight ones); a no-break space before %;
    ¿ and ¡ for every ? and !; tú to the player, as the game. Castilian groups thousands as the RAE, by a space and from
    five figures (« 1500 », « 12 500 »: `THOUSANDS_FROM`, `Format.Number`); Mexican Spanish keeps the game's comma.
    Mexican Spanish writes a decimal with a point, as the game's (`DECIMAL_SEPERATOR`), but took Castilian's texts
    through `__index`, « 0,04 % » under a row of « 16.2 % » (found by the stats session the same day): each
    Castilian text with a decimal comma gets its Mexican copy with a point as `esMX.lua` loads (nine of the card's
    today), and the language test reads every string a Mexican player gets, Castilian's under it included.
  - The rules name ASCII letters (`[A-Za-z]`), not `%a`: in some locales `%a` takes a byte of a multi-byte character,
    the no-break space's first, for a letter (seen offline: the language test took « 75 % : » for a blank).
  - `KaLiHUD_Tests` (the family's `tests/Locales.lua`) checks each language's typography on every string as the player
    gets it, and that no language names a mouse button in words.
- **The chat lines' colon** is the game's in the player's language (`ns.Colon`, `HEADER_COLON`: French's after a
  no-break space, « : » alone elsewhere); it was French's in every language. The offline game gives the French one.
- **The folder icons' names in every language (Ikar: "About icons, yes. As much as possible.").** The 112 icons the game
  has no word for were named in French and English only, in `hud/tools/make_icons.py`; their names are now each
  language's, `Locale/<language>.lua`'s `ICON_NAMES`, by the game's spelling of each atlas, German and Spanish written
  for them, Mexican Spanish's own for four (« Calavera de calabozo », « Abismo abundante », « Objetivo de
  bonificación », « Trituradora », the game's Mexican words). `Data/Icons.lua` keeps the game's word (`game`) and this
  build's French and English for a client without it; `make_icons.py` checks every icon with no game word has its English
  name and no name is for an icon not in the library. The picker: the game's word, else the language's, else the build's.
- **The mouse buttons as icons in KaLi Quest and KaLi Recipe too,** as here since 2026-11-17: « Clic droit : Déplacer
  vers un groupe » is « [right] déplacer vers un groupe », the tips' « Maj+clic » « Maj+[left] », « Clic : ouvrir le
  carnet » « [left] ouvrir le carnet ». The plain noun in a sentence (« un clic sur le suivi ») stays.
- **What the tests and the offline game read.** The smoke names menu entries and texts as the languages' files write
  them; the family's fake reads a text as a reader does (`F.Plain`: a no-break space as a space, ’ as '), and gives
  the French client's `HEADER_COLON`. Ten breaks prove the new rules, each caught (`tools/breaks/*.py`, « languages: »,
  « numbers: », « icons: », « chat: »); the 21 that quoted a Locale.lua now quote the language's file.

Nothing of it seen in game. **Checked offline only**, as all before it. To look at in game: a long French tooltip
wrapping (no « : » starting a line), a German or Spanish client's folder icons on hover, Quest's and Recipe's hints
with the mouse icons at their size.

## In game, 2026-11-23

Ikar, playing, after the cards' self-check had kept 17 cards with no gap: eight requests the same hour, built offline
the same day.

- **Several cards kept open** ("when clicking againt on a stat, it shoudl close the popup, and when clickinkg, it
  should show it on top of the stat menu. Also add a possibility to add multiple (stacking bottom uo, left to right,
  then right to left"). One card a value (`StatCard.lua`'s `pins`, by the value's key; `Stats.lua`'s `pinnedStat` a
  table). A click on an attribute whose card is kept open shuts it. A new one opens over the folder's list it was
  clicked in (`Folders.ListOf`), else over its element: the first place up from there that neither that list nor
  another card covers, then the next column to the right of them, then to the left, as far as the screen goes
  (`place`, from each card's `at`, the place it was given or dragged to). One shut leaves its place; the others stay
  where they are, as nothing moves that is being read. Their strata is `DIALOG`, over the lists' `HIGH`: the card
  kept open had stood under the list it was clicked in. Escape shuts them all. A shut card's frame is used again,
  the first made first (`KaLiHUDStatCardPinned`, then `…Pinned2`…).
- **Each row's tooltip on a card kept open** ("On hover, we shoudl show the item/spell/talent tooltip"): the game's
  own, beside the card on the side with more room (`rowTip`): the item worn (`SetInventoryItem`), the buff with its
  time left (`SetUnitAuraByAuraInstanceID`, as the buff frame does; a camp item's the camp's buff, which names them
  all), the talent at its rank (`SetTraitEntry`, as the talents' frame does), else the spell (`SetSpellByID`); a base
  says how the card works it out. The row lit under the pointer. Not on the hover's card, which the pointer can't
  reach. A tooltip shown from a row is no item or talent to try on the card (`kaliCardTip`): its talent tried would
  have drawn the card again under the pointer, and that tooltip with it.
- **The bases' formulas** ("why lvl 26 give 22 intelligence ? I told you to mark any formulas no ?", "some are 26, 22,
  11, 25 ...", "same for total life and mana from lvl"). No such ruling was in the records; the nearest were the
  question mark for what isn't known (2026-11-19, 2026-11-20) and the attack power's level written with its sum
  (2026-11-21). So, as both: the levels' row is what levels 2 to the character's have added, « Niveaux 2 à 26 », its
  sum beside it as the attack power's is (« (42 - 19 - 1) », the game's base less the race's and the class's at level
  1; the mana's, its table's at the level less at level 1). The figures differ by attribute because each class gains
  each at its own pace on the server: a table, not a formula, which Forever's files don't hold. The race's and the
  class's figures at level 1 are the original game's (`RACE_START`, `CLASS_START`), and a base that is what the
  game's figure leaves (the health's, a chance's, the energy's) is the card's reading: both wear the question mark,
  the foot saying what the game gives and what the card works out (`STAT_WHY_START`, `STAT_WHY_LEFT`).
- **What the game's figure doesn't count, on top** (`Stats.Extras`), under « En plus du chiffre du jeu », in no sum and
  kept for no report, its whole in « À savoir »:
  - the camp's mana well ("the mana regen do not takeinto account buff camp, why ?"). It gives its mana by itself, 29
    every 5 s in the data (a periodic gain, aura 24), which the game's regeneration figure, the sheet's, doesn't
    count; the camp's spirit (the banner, the lute, the fish bowl, the cosy fire) does, inside « Esprit ».
    `make_effects.py` keeps it in `HIDDEN_PARTS` since, its `every` the seconds between two gains; its figure the camp
    tooltip's line;
  - the health regained sitting or lying down ("for health regen, also show the number when sitted/asleep, and add
    that to the notes"). The sheet's grey note says 33 % more seated, and the sheet takes its standing figure for
    three quarters of what `GetHealthRegenFromSpirit` gives (`PaperDollFrameStats.lua`'s `spiritStandingPenalty`), so
    seated is the spirit's share a third more. Whether `GetHealthRegen` itself changes while seated isn't known: the
    self-check keeps a card seated that can't account for it.
- **The sheet's French full stops** ("some lines start with a '.'"): this build's French `STAT_SPELLPOWER_TOOLTIP` and
  `STAT_SPELLHEALING_TOOLTIP` write « d'un maximum de %d\n\n.Augmenté par… » and « \n\n|cffBCBCBC.Les temps… », the
  stop at the next paragraph's start. `cut` puts it back at the end of the line before it, past a colour code, an
  ellipsis left. Found by drawing every card offline with this build's French GlobalStrings loaded: the fake has none
  of them, so the smoke had never seen the sheet's texts.
- **The XP bar's bonuses** ("the xp bar shoudl also have all the bonuses listed (and the total) this include any buff
  to xp, sleeping bag, rewsted, camp, food etc."), from the game's data (`XP_BONUSES`: auras 200, from creatures, and
  291, from quests; 7 spells): the rest's (`GetRestState`'s factor, twice the creatures' while rest is left); the
  sleeping bag's « Bien reposé » (429959, 1 % a stack, three at most, from « Sac de couchage douillet »); an elixir's
  (« Élixir d'expérience infinie », 200 %); the events' (« Vents de la sagesse », « Délice du découvreur »: 50 %); a
  meal's, hidden (« Bien nourri – bonus d'EXP » 1243969, 5 % from creatures), which the meal's visible buff writes a
  sentence of after its attribute's (`XP_PARTS`, read as the camp's; its words anywhere in the line). The camp gives
  none: its tents add to the rest (« Tente d'aventurier », 20 % of a level), and « Bien reposé » 1225478 makes rest
  come faster. Each at the aura's own figures, else the data's; the sum wears the question mark, the game not saying
  how they add up (`XP_SUMMED`).

Checked offline: the static checks, the smoke, the scenarios (`pins.lua` new) and the deliberate breaks of each
(« pins: », « formulas: », « lines: », « extras: », « xp: »: 21, each caught), with the 17 they changed. One of those,
« kept open: its cross does nothing », had gone unseen since the fake learned Blizzard's close button's own click
(2026-11-22), which hides the card outside a fight: the smoke now clicks the cross in one, where only the card's own
click shuts it. The break that made a second card open beside the first is gone, that being what Ikar asked for.
Nothing of it seen in game.

## The review of 2026-11-23, and what came of it

Ikar, after the day's eight asks: "you got a list here of things you forget but I feel like you could have catched on
them, if you paused on each and asked the good question. No in game data needed. Could you, on a clear mind, review all
stats (all kind of stats) and see if there are other slippage like theses, missing stats, anything that could be
usefull for play". Each value put to the same questions (what gives it that the game's figure doesn't count; which
states change it and whether every figure covers each; whether every worked-out figure writes its sum; whether one row
adds things of different kinds; whether the game's texts show right; what a player of each class wants next), from the
game's data, code and texts alone. Found: the camp's well had been one of 56 spells that give mana by themselves every
few seconds (aura 24: Blessing of Wisdom, Mana Spring Totem, from level 26, Mana Tide, fish and soup buffs), none on the
card, `make_effects.py`'s `energizers()` having had them all; Innervate's two shares added into « +500 % », Évocation's
into « +1 600 % », and a share kept while casting alone (Méditation, Armure du mage, six talents) read as a raise of the
figure out of casting, which it doesn't change, leaving no « Autres » on any card of a class that has one; the extras'
whole out of casting alone; the seated row unmarked; food and HoTs nowhere; the defence's and the weapon skill's parts
without their sums; the spirit's card cut, the regenerations rounded; a few holy-only hit and critical strike sources
counted on all schools. Checked and right: every text of the sheet the cards format, in the four languages, against the
figures passed (only the French full stops, fixed that afternoon); the other powers' regeneration auras, which the data
leaves out. Ikar then: "Do the 2/3/4/5/6/7, the block value, spell power, let's have it per school, like resistances.
Reputation bonuses to the rep bar", and of the mana, shown two layouts on a page: "A, a table, and everything per 5s.
Add an option to show mana as per second in the settigns menu."

- **The regenerations as tables** (`Stats.RegenTable`, `RegenCard`; StatCard.lua's `columns`, a row's `cells`): a
  column a state, the mana out of casting and while casting, the health standing, seated or lying down, and in a
  fight; the totals at the foot. Out of casting (standing) is the tally the card always had, its « Autres » and the
  self-check the same. Casting (a fight) is the game's figure less what's named there, the flat changes and what the
  shares kept come to: 134 and 116 (the troll's Regeneration, kept now) are `keep`, of that column alone, each with
  what it keeps, cut so they add up; none beside a share not worked out. Seated, the spirit's a third more, marked
  (`STAT_WHY_SEATED`). Under « En plus du chiffre du jeu », `Stats.Gains`: each aura with a timed gain
  (`Data/Effects.lua`'s PERIODIC: 24 mana, 8 health, 20 a share of the most health, 84 eating's health in 5 s, seated
  only), its points the aura's, else the data's where they're the same whoever casts it, else the question; the camp's
  well from its tooltip as before. A gain on another rhythm says it under its name (« 4 toutes les 2 s »). The line and
  the head show the totals, casting (a fight) first; the game's own under the head (`STAT_GAME_FIGURE`). The game's
  `MANA_REGEN_TOOLTIP` and the energy's are left as they are. In a fight nothing is read (the auras' points hidden):
  the line keeps its last text. `Stats.Extras` and its three strings are gone.
- **Per second** (`manaPerSecond`, « Comportement et sons »): the mana's figures to a tenth, the line, the table, its
  title; the health stays in 5 s.
- **What would be on the tables**: a meal or a potion under the pointer brings its timed gains (ITEM_USES now follows
  PERIODIC's spells too: 842 items), the totals changed by them, by what the tally would change out of casting and by
  the flat changes and shares kept while casting. In Forever, Nightfin Soup's « Bien nourri » is +22 spell damage, not
  the original game's mana.
- **The block value**, a card after the block (`BLOCKVALUE`): the shield's own as its tooltip writes it
  (`SHIELD_BLOCK_TEMPLATE`: no field of Forever's data holds it), the strength's part marked, 274 and 272, items' stat.
- **The spell power by school**, as the resistances: six values under « Puissance des sorts », the sheet's icons, each
  its school's sources (13's mask), all six's counted on each, « Autres » worked out; the pet's share on the school the
  sheet takes it from. A folder made before (`db.seeds.spellSchools`, `blockValue`) gets them where a folder made now
  has them, after the mana's regeneration, so that its titles stay as a new one's.
- **Parts with their sums** (`Stats.PartSum`), **the cut** (the spirit's parts and the regenerations' totals cut as
  the sheet's « %d »), **schools on hit and critical strike** (`schoolKinds`).
- **The reputation bar's bonuses** (`Stats.RepBonuses`, REP_BONUSES): 156 every faction (the human's Diplomacy, a
  passive read as known), 190 one (Cenarion Favor on the Cenarion Circle); the sum marked as the experience's.

Checked offline: the static checks, the smoke and every scenario (`regen.lua` new), the labels; the breaks the code
moved re-targeted and those of the new code added, 44 run on a snapshot (the last 37 in one pass, 3 min 41 s), 43
caught. The one missed, « unknown: a source's amount the game doesn't give left blank », took away a guard the
« unsure » mark repeats (every source without an amount is unsure): gone. Not seen in game; to see there:
a card while eating and drinking, and one with Mana Spring Totem down, with `/kh stats`, tell whether the game's own
figures count any of it (positive « Autres » would say so).

In game, that evening (Ikar's screenshots): the block value's card said « Force 3 ? », the shield 7 and « Erreur de
l'add-on -1 » against the game's 9: the game's figure is one point less than the shield's and the strength's (the
sheet's own strength tooltip says `floor(strength / 20)`, Camelot's `BLOCK_VALUE_PER_STRENGTH`). Now the strength's
part is the sheet's, unmarked, and « Base -1 » says the point (`STAT_BLOCK_BASE_TIP`); `STAT_WHY_BLOCK_STRENGTH` is
gone. Of the sheet: "degat des sort et resistance in one column", "why spell damage and resistance have different
icons ?", "and order": the resistances under the schools in their column, the defence a column of its own; one order
for both, the sheet's resistances' (arcane, fire, frost, nature, shadow), holy, which has no resistance, last; one set
of icons, `SpellSchoolIcon2` to `7`, the only one with holy (the sheet's `UI-Character-Info-Resistance-*` atlases have
none). A folder made before gets them so once (`db.seeds.schoolsColumn`): from where the schools start, each list's
title the separator just before its first. Checked offline: the static checks, the smoke, `regen.lua`; 6 breaks
changed or new, one pass, 43 s, 6 caught. Not seen in game.

Later that evening: the defence's four (`ARMORCUT`, `MISSED`, `AVOIDANCE`, `CRITTAKEN`: `Stats.Taken`, `ArmorCut`,
their parts their sums; `db.seeds.defenseRows` after the armour), the spell power and resistances the last column
(`seedSchoolsColumn` puts them after all else). The attributes' bases: Ikar, of « Niveau 26 (49 - 23 - 1) », "if you
just backwardly calculate, then this is a useless information", "Nobody give a shit about the remainder", then "what
each level give ?", "crawl the internet": one row now, the game's base, and the levels from data. Found: the original
game's per-level table of the 40 race and class pairs (MaNGOS Zero's `player_levelstats`, the same in AzerothCore and
gunba/wow-forever-sim), Forever's race offsets the original's (its developers, forever-bugs#414). Against Forever's
sheets: a level 1 human warrior matches (the paragraph after next: one sheet, not eight); a dwarf shaman doesn't (26: agility and intellect one lower; 60,
wowsims/forever's EV-0181: strength 3 higher, agility and intellect 3 lower), no table found matching it (TBC, WotLK,
Cataclysm's own dwarf shaman, MoP, AzerothCore, wowsims' rows; Forever's client has no such table). So
`Data/BaseStats.lua` (`make_basestats.py`, the source in the reference folder) gives what a level gives where the game
hasn't said; the game's own, at each level-up (`PLAYER_LEVEL_UP`'s deltas), is kept in `db.levelGains` by « race
class » and wins; a card says where the game's base isn't the table's (`Stats.LevelLines`). Checked offline: the static
checks, the smoke and the scenarios; the breaks of the removed split dropped, none added for the new code (Ikar: "fuck
your tests"). Not seen in game.
Then Ikar: "why now that you have the table can't you split to race, class and level ?": the table is now each
class's row as a human's (what most races agree on, their offset taken off: the original table's human warrior has 21
spirit at level 1, Forever's sheet 20) plus the race's offset, which gives the level 1 warriors of #414 to the point;
`Stats.BaseSplit` splits it, the race's (20 and its offset), the class's at level 1, the levels' since, and « Forever »
the game's base less the table's (`STAT_FOREVER`, its hover both figures), none where they agree.
Then Ikar: "Are you sure you nailed the lvl 1 stats for everyone in forever ?": no. Of #414's eight level 1 warrior
sheets, read the day before the fix, only the human's holds (its seven others are the bug's, its expected rows the human
sheet plus the original offsets, a sum): so the « match » above is one sheet, a human warrior's, and no other class's
level 1 sheet has been read. Forever has 56 race and class pairs (its client's CharBaseInfo), the original 40: the 16
others (an undead paladin, a human hunter, a dwarf shaman, a gnome priest, a troll warlock, an orc mage, ten Skyborne)
are their class's row plus their race's offset, which the dwarf shaman's sheets don't bear out. The two Skyborne races
share one race token and had no offset: theirs now, read from level 1 sheets (wowsims/forever's EV-0093, 2026-11-06:
High Order -3, +4, -1, +4, -3; Windshaper -4, +3, 0, -1, +3), the offsets keyed by race ID (UnitRace's third) and
their race row's hover saying where they come from (`STAT_RACE_READ_TIP`).
Then Ikar: "Go and check then": every level 1 figure published for Forever, Warcraft Tavern's race guides (52 of the 56
pairs, all but the Windshaper warrior, hunter, rogue and druid), is the table's, all five attributes; the guides don't
say they were read in game, and their one Skyborne row per class (High Order's offsets, the shaman's Windshaper's)
suggests the same sum. Read in game: the human warrior's sheet (#414), the Skyborne offsets (EV-0093), and a naked level
30 undead warlock before the fix (wowsims/forever's EV-0076: Stamina 44, 39 × 1.15 Demonic Embrace; armor 62, Agility
31), which the table gives with that day's offsets. Nothing on wowsims' tracker, Forever's, foreverdb.net or Zockify
holds another class's level 1 sheet.

Then Ikar, of the base's gap row: "change the Forever to Forever tweaks", and of its hover's "the original table gives X
at level N": "the level 26 +1 original table is bullshit information, remove that". The row is « Ajustements de
Forever » (`STAT_FOREVER`), with no hover of its own: the original table's figure for a level is never shown.

Then the ready-made folders (Ikar: "I am affraid that you build a whole update machinerry. Maybe we could avoid that
nightmare by making them read only ?"): locked folders, as « Locked folders » in the hub's part says. Of the
language (Ikar: "When switchign languages, the folders, and the optiosn in the settings, and the emotes, and the built
in folder headers did not update, the stats did though"): a folder's, a macro's and a separator's text is saved, so it
stayed as first made; a locked folder's is the code's at each login now, « Add-ons »'s and « Suite »'s names too. The
options save no text: which one stayed in the other language isn't known yet (asked).

Then Ikar: "did you remove the data conversion ? Simplified the code, updated all the doc, reviewed your changes ?".
KaLi HUD has never been published, so what converted a game saved by an earlier build only served his. Gone: every
step made once for it, each with its mark in `db.seeds` (`emote`, `emotes`, `infos`, `reputations`, `sources`,
`titles`, `perLine`, `tags`, `markers`, `clearSigns`, `stats2`, `healthRegen`, `spellSchools`, `blockValue`,
`schoolsColumn`, `schoolsLast`, `defenseRows`; only `overflow` stays, « Suite » being made once); the data sources'
pinning (`pinSources`, the review of 2026-11-17, second round, 9); the launchers moved into « Add-ons » for a file from
before folders (`newFolders`); two folders saved open at once narrowed to one; a renamed macro's seed taken off; and,
in the locked folders' rebuild, what fitted a game saved before the lock to it (an item of theirs placed elsewhere made
a copy there, a macro of theirs elsewhere made the player's). A locked folder not there is made at the next login, one
step for a first install and for one a later build adds; each is made on its own, whole or not at all, so R5 still
holds. Found on the way: a locked folder put in a folder of the player's was deleted with it, with nothing to make it
again before the next login; now it's taken off the HUD, as ours are (`Folders.Delete`). His saved game, read: nothing
in it for the removed conversions to act on. `Seeds.lua` 618 lines to 478. Checked offline: the static checks, the
tests, the smoke, the restart, the scenarios; 6 breaks re-pointed, 1 added, 5 dropped with their code, none run. Not
seen in game.

Then Ikar: "you still kept the Level 26 in the main state note (+1) etc, unecessary. Remove thoses": an attribute's
card no longer says what its level gave and what the next will. Gone with those lines, as nothing else read them:
`Stats.LevelLines`, `Stats.LevelGain`, `Stats.TableBase` (read by nothing already), the level-up's record and
`db.levelGains`, and their three strings. The base's split (the race, the class at level 1, the levels since,
« Ajustements de Forever ») stays. Checked offline: the static checks, the smoke, the scenarios. Not seen in game.

## Issue #5 and the requests of 2026-11-24

Ikar's mail of that evening, [issue #5](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/5) (« Bug puissance des
sorts », its subject alone: what was wrong with the spell power isn't said, asked), and in the session: "why mana and
health are not broken by race, class and profession like the rest", "KaLi hud need an option and report bug in the
right click menu, like the kali quests", "Healing power is missing, add a category bellow defense for healing related
stats, investigate if there is other healing related stats to count".

- **The attack power's class part below 0** (the report's first card, a level 26 night elf druid: « Erreur de
  l'add-on -20 »): LEVEL_AP's own figure for a class whose level adds nothing (a druid's -20, a mage's, priest's and
  warlock's -10) was a base row, and every base row below 0 is renamed the addon's mistake. It is the table's figure,
  never a rest: `measured`, as « Ajustements de Forever » is. Every druid, mage, priest and warlock had it.
- **The block value without a shield** (the second card: strength 33, the game's 1, « Autres 1 »): the point taken
  off the shield's and the strength's together (the screenshot of 2026-11-23: 7 and 3, the game's 9) is taken off with
  a shield alone. Two readings, one each way: a third, a shield and a strength just past a multiple of 20, would tell
  a cut from a rounding.
- Both cards are cases in `hud/tools/lua/scenarios/cards.lua`, held to no gap; the block value's `freshParts`, its
  parts worked out again from the state kept, the fix being in them.
- **Health and mana split** as the attributes' are: the class's at level 1, then what levels 2 to N have given. The
  mana's from Forever's own table (BASE_MANA, PlayerExpectedStat), the health's from the original game's
  (`player_classlevelstats`, `Data/BaseStats.lua`'s `health`, by `hud/tools/make_basestats.py`): Forever's data has
  none of the health's. No race row: neither table has one, a race giving its stamina and intellect, which their own
  cards split. Checked: Ikar's level 26 dwarf shaman, 767 health of which 510 its stamina's, leaves 257, the table's;
  Forever's mana table is the original's for druids, warriors and rogues at every level, all but level 1 for hunters,
  paladins and warlocks, 55 of 60 levels for shamans, and below it for priests and mages. What the game's figure
  leaves of either is « Autres », below 0 the addon's mistake. The fake's level 23 warrior has 1013 health now, the
  table's 243 and its stamina's 770 (a made-up 1520 until then).
- **Options and Report a bug** in the info bar's menu, between what can be made and undo and redo, which stay last.
  « Options » is the game's word (`OPTIONS`).
- **Healing** (the damage meter's word, `DAMAGE_METER_CATEGORY_HEALING`) under the defence's four, in its column:
  the sheet's « Soins des sorts » moved there from the modifiers. Looked into for more: Forever's `GetSpellCritChance`
  takes no school (one figure, already the critical strike's spells part); the healing taken (auras 115 and 118:
  Mortal Strike's -50 %, Amplify Magic's +45, Tree of Life's +10 %), and the healing done by a share (136: Power
  Infusion's +20 %) are in the data, but the healing talents (Spiritual Healing, Gift of Nature, Purification, Healing
  Light) change some spells only (spell modifiers, 108), which no card reads: a healing done that left them out would
  mislead. Asked which to build.
- Ruled then: "add the healing taken", and of the talents "I don't understand why we can't take into account the
  talents", "heal power should count only when it affect all spels. Or the main spells at least. Simple to check no ?".
  Built: **Healing Taken** (118, by a share, the shares multiplied, the original server's), **Healing Taken per Heal**
  (115, points on each heal) and **Healing Done** (136, by a share). A healing talent is aura 108 on the spells its
  codes take in (SpellClassOptions, now fetched): `make_effects.py`'s `heal_talents` writes it as 136 when its codes
  take in all its class's main heals (`MAIN_HEALS`: the priest's Lesser Heal, Heal, Greater Heal, Flash Heal, Renew,
  Prayer of Healing; the druid's Healing Touch, Regrowth, Rejuvenation, Tranquility; the shaman's Healing Wave, Lesser
  Healing Wave, Chain Heal; the paladin's Holy Light, Flash of Light). Kept so: Spiritual Healing (3, 7, 10 %),
  Purification and Gift of Nature (2 to 10 %), Healing Light (4, 8, 12 %); left out: Improved Renew, Improved
  Rejuvenation, Healing Way, Twin Disciplines, Genesis. None of the three has a game figure: no « Autres ».
- **The attack power's base** in two rows (Ikar: "why it is not just base = -20 for everyone, isn't the chaman getting
  attack power that a druit do not ?", "base shoudl come before level", "Level 26 (x2)"): « Base » (-20, or -10 for
  the casters and every ranged), then « Niveau 26 (x2) » for a class its level raises. LEVEL_AP itself unchanged
  since 2026-11-21: checked in game on the shaman at 24 and the druid at 26, the other classes not.
- **A source's name cut short** on a card (« … » where its figure starts): two lines at most now (`SetMaxLines`); one
  still cut shows whole in a tooltip on the card kept open (`IsTruncated`; Ikar: "when there is an elipssis, there
  shoudl be a tooltip with the full data, better, write it in 2 lines").
- `tools/breaks.py` holds the five minutes itself (Ikar: "did you screw the 5min rule again ?", eight minutes for seven
  breaks that day): a link to the whole smoke is refused, the break skipped with what to do; a run stops at BUDGET;
  `--link` says its breaks were run. The health's and mana's breaks link to the scenario `bases`.

Checked offline: the static checks, the smoke, the scenarios, the new breaks. Not seen in game.

## The breaks made quick, the night of 2026-11-24

Ikar, once 0.9.1 was out: "you have all the night to refactor this nightmarish test break that slow you own
constantly". The family's tools, for the three addons; nothing of the addons themselves changed.

- **The fake game's frames.** `F.LayoutPass`, at every pass of `F.RunTimers`, read `scrollChild` on every frame ever
  made, through the frame's metatable: each read a walk of the method prefixes (`isMethodName`), 85 % of KaLi Quest's
  smoke. Read raw now, and `isMethodName` keeps its answers: the HUD's whole smoke 37 s → 11 s, KaLi Quest's 7 s →
  half a second, the same results.
- **Each runner made of parts** (`tools/kali/checks.py`, "The parts of a run"): `--only static`, `tests`, `smoke`,
  `shared`, `labels` (KaLi Recipe's `restart` too; this addon's `alone`, `scenarios`, each scenario), `--at` the
  smoke's block or one of the static checks (`api`, `needs`, `effects`...). `shared` and `labels` after a login alone,
  under a second; a whole run still plays both after the smoke. A smoke's `--at` that no line holds fails now: it had
  run the whole session, without a word, for seven of this addon's links. Each failure of a smoke says the block it
  came from (`checks.smoke_run`), a check whose words are made as it runs too.
- **The game's files read once a process** (`@cache`: Blizzard's source, the API docs, the build's tables, the
  generators' builds).
- **`tools/breaks.py`** runs each break against its link only, in workers (`tools/kali/worker.py`: a runner loaded
  once, on its own copy of the addon), eight side by side. Each link the breaks use runs first on the code as it is,
  and must pass; a break with no link, one to the whole smoke or to a line gone aborts the run before anything runs; a
  part that hangs is stopped at ten times its own time. `--link` finds what's missing: the quick parts first, then the
  whole smoke once, for the block its first failure came from, which must catch the break alone.
- **Every break linked**, 1,004: KaLi Quest's 67 run in 6 s, KaLi Recipe's 84 in 9 s, the shared code's 95 (257 runs,
  in each addon it touches) in 28 s, this addon's 758 in 7 minutes, a change's few in seconds. Before, a break of KaLi
  Quest, KaLi Recipe or the shared code ran its whole runner, and the guard refused all 246; 230 of this addon's had
  no link or the whole smoke.
- **Twenty-two breaks no test caught**, the whole run included, the checks having moved from under them. Ten had no
  link, twelve one to a check that no longer caught them, a whole sweep showed (none had been run since):
  - « Add-ons » and « Suite », KaLi HUD's folders that aren't locked: « Retirer » in their menu, not « Supprimer le
    dossier »; renamed, the player's, its role gone and what stood in it by default saved there, its menu without
    « Retirer » beside its own deletion; and the bar's menu without the macros when one of the player's is on the bar.
    The smoke's checks ran on a locked folder, whose menu is another's, and on a bar with no macro of the player's
    (scenario `bundled`).
  - « Suite » made again from the bar's menu, the folder that takes what doesn't fit (scenario `overflow`).
  - Blessing of Kings' share in the game's base: since the table splits the base, its rest went to « Forever », which
    hid a base of 110 (the Kings check now holds the card's sources the same, the game's bonus 11 or 21).
  - A camp's line without a figure took the next line's (a case beside the lute's).
  - A class the tables don't have, the only one still to meet the base names « Niveau 23 Humaine Moine » (scenario
    `noclass`).
  - The folders' titles in the game's words (scenario `titles`).
  - The hit chance's « Effets », each kind's; a source of one school on the spell penetration's card, named with it
    (the spell power's cards are a school each since 2026-11-23); a value nothing changes, its skill all the same and
    a set's next pieces: the defence, the armour's sources coming from its whole since 2026-11-19, so never unchanged
    as the smoke's case took it (scenario `rows`).
  - What would be with an item under the pointer: the attack power's base rows as without it, and the question mark
    for a buff of no known figure, the smoke's meal now sure of its figure (scenario `would`).
  - The game's notes: the raid boss's figures above « Effets », not its name alone; an element sent into a folder lit
    by a flash of its own, the one before having lit the same button; the spell schools' order, held by the smoke's
    list of the folder, not the scenario `regen` it named.
  - Three went, the code they broke never reached: `Seeds.lua`'s `sepSpec` for a title given as a function
    (`Seeds.ContentsOf` gives it the words first), the bar's menu's « reputations » (each reputation lives in its locked
    folder), and the parts' rest of `sourcesOf` (the attack powers alone have parts and the game's base, and their
    level's rows put it aside).
- `tools/run_tests.py` runs the three runners side by side: 34 s for the whole family, where the HUD's run alone had
  taken over a minute.

Checked offline: each runner whole and part by part, every break against its link. Nothing to see in game.

## The smoke's breaks made quick, 2026-11-25

Ikar, of the night's report (this addon's 758 breaks in 7 minutes): "hud smoke test then ?". 547 of them run against a
block of the smoke, and each paid first for all that stands between the blocks, 1.96 s; 294 for the block of the bar's
other items too, 2,949 lines.

- **What stands between the blocks, 1.96 s → 0.88 s.** Five of its sections are blocks of their own, left out when
  another is asked for: the cartouches' styles, a folder's list with its separators and values, undo and redo (each a
  `run(function() ... end)`, its own scope already, now a `do`), the borders and backgrounds, and the commands
  (indented into one). Nothing after them stood on what they leave. What remains is the session's start, whose names
  the blocks use: the login, the plate following in Edit Mode, the hub and the info bar.
- **The bar's other items cut in five**: the folders, the skills, the attributes (1,795 lines, 168 breaks, a quarter of
  a second), the readouts, then the separators, folders and macros. What they share (its folders and macros, the
  errors kept, an item's text, a folder's members) stands above them; each counts the errors from its own start. No
  name was lost: the session reads the same 7 globals that aren't there, before and after.
- **A failure says the line it came from** (`checks.smoke_run`): the session's own line that was running, its check or
  the call that led to it (« smoke: its first failure from the block at line N, at line M »). `--link` names the
  block by a text of that statement, which stays with its check when a block is cut up.
- **64 links found again**:
  - 18 caught by the sections now blocks, at `--at 0`;
  - 37 that named the old block by its first line, the text taken when no line held what failed: that line went with
    what the five share, and they would have run no block, without a word (`stale()` sees a text gone, not one moved
    out of its block);
  - 9 whose text went to the attributes, caught all along by a folder's list between the blocks.
- Each worker's run compiles again only the file the break was planted in (`checks.compile_problems`, 0.15 s a run).
- **Every break caught**: this addon's 758 in 219 s (416 before), the shared code's 95 in 21 s, KaLi Quest's 67 in
  5 s, KaLi Recipe's 84 in 9 s.

Checked offline: the three runners whole, each new block alone, every break against its link. Nothing to see in game.

## The whole run made quick, 2026-11-25

Ikar: "Is there time to be saved on runnign tests ?". The family's whole run took 47 s, all of it this addon's runner,
whose parts ran one after another: the static checks 21 s, the smoke 14 s, the scenarios 10 s. 13 s of the static
checks went to reading the game's files again at each run: Blizzard's source (4,142 files, 5.8 s, in each of the three
runners), the API docs' lists (1.7 s) and Effects.lua made again from the build's tables, to hold it against the
addon's (5.7 s).

- **What is read from the game's files is kept from one run to the next** (`tools/kali/kept.py`, in `tools/.cache/`,
  which git leaves out). A result is used again only while every file it was made from keeps its path, time and size
  (a walk of Blizzard's source: 0.26 s) and the code that reads them is the same; anything else makes it again, one
  slow run. The static checks: 22 s → 4.5 s; KaLi Quest's and KaLi Recipe's, 11 s → 3 s.
- **A whole run plays its parts side by side**, each in a process of its own (`checks.side_by_side`): as long as the
  smoke, 12.7 s, not their sum, 46 s. Each part's process hands its problems to the whole run (`--report`), which says
  them once; one that ends without them (it raised) is said so, its traceback above.
- **The scenarios run side by side in threads**, each in its own Lua state (lupa lets go of Python's lock while Lua
  runs): the 25 in 3.5 s, not 9.2.

The family's whole run: 47 s → 18 s. What's left is the smoke: ~12 s alone, ~16 s beside the rest of the run, which
takes the cores it shares. 40 % of it is this addon's geometry, worked out again at each change of the session's
settings, 30 % the fake game. Cutting the session into pieces run side by side would lose what each part leaves for the
next, and the restart check reads the file the whole session writes: not done. Loading the addon precompiled would
save 0.06 s of the 0.11 s each game's load takes: not done.

Checked offline: the three runners whole, from nothing kept and again; a fault planted in a copy, and a copy whose runs
crash, each said; 15 breaks against the scenarios, the tests and the smoke, and the 5 against the static checks.
Nothing to see in game.

## The tests reviewed, 2026-11-25

Ikar: "do a ful lreview of the the tests, see if everything is correct, maintainable, well documented, well
organized", then "fix everything".

- **The enums check alone** (`--only static --at enums`) took two of KaLi Quest's enums for unknown: Blizzard's own,
  which it knew only once the api check had read Blizzard's source. It reads them itself now (`game.blizzard_enums`).
- **The family's runner dropped the options' values**: `tools/run_tests.py quest --only static` handed each runner a
  bare `--only`, which raised. Every option goes with its value now.
- **The scenarios' threads each read the build's files again** as they started, eight readings at once. They are read
  once before the threads start: 2.8 s, was 3.3.
- **What reads the game's files has a file of its own**, `tools/kali/game.py`: what it reads is kept while it and the
  files stay the same, so an edit of the checks no longer costs a slow run.
- **The parts every runner has are the family's** (`checks.tests_part`, `smoke_part`, `after_smoke`, `shared_part`,
  `labels_part`). The three runners had each their own, which had begun to differ: KaLi Quest's smoke loaded its probe
  without looking, KaLi HUD said "shared smoke:". One login for them all, the game's first (`PLAYER_ENTERING_WORLD`
  with `true, false`: no code of the three reads them).
- **A smoke's blocks are found in one place** (`checks.smoke_layout`), which fails a block that doesn't close on an
  `end` alone at the margin. A line such as `end)` at the margin ended a block unseen before, the rest of its checks
  then run as what stands between the blocks.
- **The links kept for nothing are said** (`breaks.stale`), and `--link` drops them: 34 for breaks gone or renamed and
  6 for breaks that name their own `test:`, all KaLi HUD's.
- 15 functions of the fakes that nothing called are gone, with the smoke's two lines that set the pointer's frames for
  one of them (the addon no longer asks what's under the pointer); a dozen comments gone stale say what is.

Checked offline: the family's whole run, ALL PASS in 19 s; the enums check alone in each addon; the readings kept
before and after the move, the same; a block cut short, said; the three smokes' blocks, the same as before; every
deliberate break against its link, 1,004 of 1,004 caught (shared 95, quest 67, recipe 84, hud 758). Nothing to see
in game.

## What would be on the lines, 2026-11-25

Ikar, of the light blue: "when hovering, it seems you turn blue only the individual cards, not the whole stat lists, is
that true ?" It was: what is under the pointer was tried on the cards kept open alone. Then "go for an
implementation", after the two points I had put to him: what it costs, and a line that would widen ("120 → 130") on
the game's doing, which the static rule forbids (the figure alone keeps the line's room).

- **Each line that shows says what its value would be**, a card kept open or not: the attributes' folder open (it
  opens on a click by default, and stays open while the pointer is in the bags), or a copy of one of them on the bar
  or in a folder (`Tried.Shown`: its button visible). Its figure alone in the light blue (`7fd4ff`), written as the
  line writes it (a chance to a tenth, the block's and the speed's whole, the defence's most beside it, the off
  hand's expertise beside the main's), where the card's head says it: the same sum (`wouldBe`). The game's question
  mark where that can't be said; the line as it is where nothing of it would change. Its name and its numeral stay,
  the thresholds read at the value as it is, as the card's « À savoir » (mine). The mana's and the health's
  regenerations say their two states as their line does (`Stats.RegenLineWould`, whose sum the card's head shares);
  the healing's shares, which their sources alone make, are read again with it in place.
- **Worked out once for what is tried.** The game refreshes an item's tooltip five times a second (GameTooltip's
  OnUpdate asks its owner's `UpdateTooltip`), and each refresh had tried the same item again and drawn the cards kept
  open again. What is tried is now written whole (`Tried.Key`): the same again changes nothing, for the cards as for
  the lines. The lines that show are then worked out eight a frame, the attributes' changes once for them all
  (`Tried.With`): a whole folder is some fifty readings of the sources, about 40 ms in the tests' game, which in one
  go would have stalled a frame or three at each item. Worked out again as the values are read again (the sheet's
  events); nothing in a fight, and a line the fight hides says what it was before anything was tried.
- **A question only where the value stands on it** (mine, found by the lines): an attribute whose change can't be said
  (a consumable's buff of no known figure on the stamina) put the question mark on every value tried, the resistances
  too, and would have put it on every line. The attributes a value's readings ask for are noted (`Tried.leaned`, in
  `attribute`): the question is the stamina's and the health's alone, on the cards kept open too.
- **Stats.lua is at Lua's limit** of 200 locals in its main chunk, a loop's five among them (it was at 195): what is
  tried holds in one table (`Tried`), in place of the local that held it.
- **The fake game's `IsVisible`** said a button visible while the list it stands in was shut; it asks the frames it
  stands in now, as the game does (`tools/lua/fakewow.lua`).
- The line's numeral showed an error's text the one time its thresholds raised one (`ns.SafeCall` gives `false,
  err`); none then.

Checked offline: a scenario of its own (`hud/tools/lua/scenarios/lines.lua`): a shut folder works nothing out; open,
the lines the item changes, in the light blue, the defence's « x / most »; the same item again reads nothing; the
lines as they are once the tooltip has gone; a copy follows, the folder shut; a buff of no known figure asks on the
stamina's and the health's lines alone; the healing taken by points; the mana's two states; values read again under
it; a fight. The smoke's consumable whose buff is on now sends the buff's coming, as the game does, before it is
hovered again. 13 breaks, all caught, and the 53 of what would be, the cards kept open and the regenerations again.
**To see in the game:** the folder open, items hovered in the bags: whether the lines fill without a stutter, and
whether the light blue reads on them.

**Reviewed the same evening** (Ikar: "do a ful lreview of the changes. Make sure they are correct"). Six things found,
each confirmed in the code, each fixed:

- A buff of no known figure on the spirit asked nothing of the regenerations any more: their spirit's share is the
  game's figure, which no reading of the attribute's says, so the question taken to what a value stands on had left
  them out. `untold` asks the spirit's own question now.
- A drink or a meal tried whose gain every few seconds has no known figure: its row asked it, but the totals left it
  out, so the card's head said the regeneration as it is, in the light blue, and the line said nothing. Both ask it now
  (`regenTried`'s fourth result); the head's had been so since 2026-11-19.
- A change smaller than the line writes (1 agility, 0.01 % of critical strike) turned the line light blue on the same
  figure; the line stays as it is then, the card kept open saying the change to the hundredth.
- The armour penetration's figure is written as its line writes it, with no thousands' mark (`%d`).
- Each of the sheet's events under an item worked every line out again; most change no value (a stack split, an aura
  of nothing the sheet shows): only an event after which a value reads otherwise does now (`Tried.values`).
- A value its sources alone make, read again with what is tried, kept an error to itself: it is raised, so the line
  is let go for the session and the error kept, as any other.

Checked offline: the scenario's new cases (the spirit, the drink on the line and on the head, the change too small, an
event that changes nothing), the six breaks that undo them, all caught, with the 70 of the lines, what would be, the
cards kept open and the regenerations; the family's whole run, ALL PASS in 13 s.

## A folder that stays open, and a darker blue, 2026-11-25

Ikar: "can we add another option for menu, on top of default, auto hide, a persist option ? when clicking outside do
not close the menu ? and make it default for stats. What are the other options currently ?", and while it was built,
"the blue is hard to differenciate with the green, maybe let's make it darker".

- **A fourth way of opening, « Au clic, reste ouvert »** (`persist`), after « Au clic » in the folder's « Liste »,
  « Ouverture »: opened by a click, a press elsewhere leaves it open (`pressed`); a click on its button shuts it.
  Mine, to rule if they matter: another folder opening shuts it still, the one-at-a-time rule (Ikar 2026-11-16) being
  about menus opened, not clicks elsewhere, and two lists opening up from neighbouring buttons would stand on each
  other; in a fight, « Fermer les dossiers en combat » shuts it as one opening on a click, once the pointer has been
  on it and left (the option's own words: "même s'il s'ouvre au clic"). A login keeps it open, as « Au clic ». What
  shuts on leaving is said in one place now (`shutsOnLeaving`: « Au clic, se referme quand on le quitte » and « Au
  survol »), where five tests of « not click » would each have taken the new way for one that shuts so.
- **The attributes' folder opens so** (its spec's `open`): a locked folder shows no settings (Ikar 2026-11-23: "No
  edit, no reset"), so the way it opens is the code's, set again at each login by `settle`, which had cleared a
  spec's way of opening without taking it. No save conversion: the spec reaches every game at its next login.
- **The blue of what would be is darker**: the game's own `RARE_BLUE_COLOR` (`0091f2`, this build's GlobalColor
  table), 0.27 of light where the sheet's green (`20ff20`) has 0.72 and the light blue (`7fd4ff`) had 0.59: the two
  now as far apart as 2.4 to 1 where they were 1.2 to 1, and the blue still 5.4 to 1 on the dark floor. The
  bluer of the game's blues of that lightness (`HIGHLIGHT_LIGHT_BLUE`, `3e91ff`, the same), and the item quality's
  rare blue (`0070dd`) is darker still: not in this build's tables. The cards' hint « en bleu » wears it in each
  language.

Checked offline: a scenario of its own (`hud/tools/lua/scenarios/persist.lua`): the attributes' folder stays open; a
press elsewhere leaves it open and shuts one opening on a click; another folder opening shuts it; its button shuts it;
the pointer gone, it stays; a login keeps it; a fight's rule; the menu's choice after « Au clic », which then stays
open. The saved data keeps the new way and drops one it doesn't know (KaLiHUD_Tests). 8 breaks, all caught, with
the folders', the presses elsewhere', the lines' and what would be's: 87 of 87. **To see in the game:** the folder
open beside the bags, and whether the darker blue reads on the lines and the cards.

**How a locked folder opens is the player's** (Ikar, the same evening: "users shoudl be able to set opening behaviour,
even on locked folders"), the one exception to "No edit, no reset" (2026-11-23). Its menu has « Ouverture » under the
note that a drag takes a copy, the four ways, its spec's ticked till another is chosen. What is saved (`open`) is the
player's choice alone; unset, a folder KaLi HUD makes opens as its spec says (`defaultOf`: the attributes' « Au clic,
reste ouvert », the others « Au clic »), so a later build's spec reaches a game where nothing was chosen, and the
spec's way chosen again is saved as nothing. The making again at each login (`settle`) no longer clears it, nor
writes the spec's way in it, which it had done since the afternoon only, in no published build: no save to convert.

Checked offline: the scenario's new case (the attributes' menu offers the four, its spec's ticked; « Au clic » chosen
holds through `Seeds.Sync` and a press elsewhere then shuts it; its spec's chosen again saves nothing), 3 breaks for
it, all caught, with the folders' and the stays-open's: 52 of 52.

**Reviewed again the same evening** (Ikar: "review your changes"). The folders' and the locked folders' changes were
found right; four things in the lines', each confirmed in the code, each fixed:

- Each of the game's tooltips of an item or a spell now asks whether a line shows (`Tried.AnyShown`), a card kept open
  or not, and a copy's line through the saved data. With none (refused, as a newer version's is, all session long),
  each erred, five times a second under an item. No copy is asked of then.
- The speed's line, read each second with no event of the game's, kept what it would be as first worked out: into the
  water with a potion of swiftness under the pointer, it still said the running's. A line that reads otherwise has
  what it would be worked out again (`updateOne`). What every line stands on (`Tried.full`, the attributes' changes)
  is still worked out again with them all as any value changes; a new case needs it now (a share of the strength
  come: the attack power's line, whose own figure stays), the old one passing on the line's own change.
- Each of the sheet's events read every value twice (to see whether one changed, then for the lines): once now.
- The armour penetration's figure was rounded where its line cuts (`%d`): cut now.
- What still said the light blue (the scenario's words, the smoke's, three breaks' names and their link) says the
  blue.

Checked offline: the scenario's three new cases (the water, no saved data, the strength's share); 2 new breaks, all
caught with the 17 other breaks of the lines, the one the speed's fix had let pass caught again by the share's case;
the two breaks whose text or name moved, caught; the family's whole run, ALL PASS in 26 s, each of the 1,034 breaks
still applying where it goes.

**In game the same night** (Ikar, hovering items with cards kept open: "when hovering an item, it doesn't seems to
update everything, the output for example", "mana regen seems also to have hard time showing the new values, see the
rest", "damage reduction too"). Three kinds of figure read the game's at the values as they are, never what is tried:

- The card's « Effets » (the output, Ikar's word of 2026-11-20 for the right column): each figure the value gives
  (`GIVES`) read its value from the game. Now read again with what is tried in place (`Tried.Effects`), each beside
  what it is, the arrow and what it would be in the blue, as the sources' rows: the attack power and the block value
  of the strength, the dodge of the agility (followed point for point, `Tried.DodgeFromAgility`), the damage
  reduction of the armour, each kind of attack's hit, critical strike and haste (their own kind's sources read:
  `Tried.channel`), the block value, the defence's share, the resistances'. The game's sentences in that column for
  the values without figures (the dodge's, the expertise's: the value itself, which the head says) stay as they are.
- What is worked out of another value: the damage reduction its armour (« Réduction des dégâts »), the misses and
  critical strikes taken their defence, all they don't land the dodge, the parry and the block, which take the
  defence's share. Each reading now adds what is tried's change of the value it stands on (`Tried.Change`: the same
  sum as that value's own line, once for what is tried, its question with it, which what stands on it asks); the
  critical strike's weapon skill is the weapon tried's (`weaponSkill` through `wornLink`: an axe tried where a sword
  is, no swords' skill). A row whose name holds a figure of what is tried (« Armure 1 540 », « Défense (153 - 115) x
  0,04 % ») keeps its place, its figure changing (`match`), no longer a row gone and another come.
- The spirit's share of the regenerations: the game gives it at the spirit now alone (`GetManaRegenFromSpirit`), and
  what would be had worn the question mark since 2026-11-19. Searched (Ikar's rule of 2026-11-23, "hunt the data"):
  Forever gives every class 6.25 + spirit / 8 mana a second, the original game's priests' and mages' sum, in both of
  Forever's sims (wowsims/forever's sim/core/mana.go, which tests it the same for every class; gunba/wow-forever-sim,
  from the beta's hunters and paladins); Ikar's dwarf shaman had 13.75 at 60 spirit on 2026-11-23 (its statChecks),
  this sum's to the hundredth, where the original game's shamans' 17 + spirit / 5 a tick gives 14.5. One reading
  can't tell its slope (15.5 + spirit / 5 a tick gives 13.75 at 60 too): the sims' says it. The mana's share now
  follows the spirit tried (`Tried.ManaFromSpirit`: the game's figure by the sum's ratio, so that a share the game
  raises it by is followed), on the line, the card's table and the spirit's card. The health's keeps its question:
  no sum of Forever's found (neither sim models it), and the original server's (a shaman's spirit x 0.28 - 3.6 a
  tick) isn't Ikar's readings (33 in 5 s standing at 64 spirit, where it gives 34).

On the way, a mistake caught by the smoke: the card had first taken what the lines worked out (`Tried.full`), which
waits for a value to change; an aura come with none (the smoke's consumable drunk under the pointer) left its effects
saying the buff again. The card works its own out anew at each drawing, its effects with it (`data.tried`).

Checked offline: the lines' scenario's new cases (a chest's 10 defence on the misses, the critical strikes taken, the
dodge, the parry and the avoidance, the block at 0 and the damage reduction left as they are; a chest's 200 armour on
the armour and its damage reduction; the armour's, the strength's, the damage reduction's, the critical strike's and
the spirit's cards kept open; an axe tried where a sword is; a helm's 10 spirit on the mana's line, the health's
asking); 13 new breaks, all caught, with the 24 others of what would be and of the lines; the 12 whose text had moved,
retargeted, caught; the family's whole run, ALL PASS, each of the 1,047 breaks still applying. Not seen in game.

**Reviewed on 2026-11-26** by the session that took the work over (Ikar: "take over the work of the previous session
... And do a ful lreview of what was done"): the family's whole run (ALL PASS, 14 s) and every deliberate break run
once, not only those named. Three things found, each confirmed in the code or by a run, each fixed:

- The spirit's card kept open said its health as it is under a consumable whose spirit has no known figure, for a
  class without mana: its effects' readings named the spirit through the mana's alone (`Tried.ManaFromSpirit`).
  `GIVES.SPIRIT` says now that both its figures stand on the spirit (`Tried.leaned[5]`); a case of the lines' scenario
  (no mana, the card kept open, the question on the health) and a break.
- The break "lines: still said once the tooltip has gone" was caught by nothing: the scenario looked at the lines only
  after an aura's event, which reads them all again. In the game they would have kept the blue till the next event.
  The scenario looks at them as the tooltip goes, before any event.
- The break "editor place: a shut list's member taken for shown, by its last place" was caught no more since the
  fake's `IsVisible` asks the frames a button stands in (this evening's): `b:IsVisible()` already says a shut list's
  member isn't shown, so the list's own test beside it is a second guard of the same, and undoing it alone changes
  nothing. The code is right as it is; the break undoes both guards now, the defect it is named for.

Not seen in game, as the rest.
