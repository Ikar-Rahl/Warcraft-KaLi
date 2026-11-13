"""Deliberate breaks of KaLi Recipe's own code: each one undoes a fix, and its tests must catch it.
Run with: python -I tools/breaks.py tools/breaks/recipe.py [word]
The first ones undo the review of 2026-11-11, whose false alarm came from Ikar's game, not from the tests.
"""
GAME, SCAN, MAIN, CHECK, DB, NOTEBOOK, MINIMAP, SOUNDS, OPTIONS, FOLLOW, MODEL, TEXT, CHAT, LOCALE = (
    f"recipe/addon/KaLiRecipe/{name}.lua"
    for name in ("Core/Game", "Core/Scan", "Core/Main", "Core/SelfCheck", "Core/DB", "UI/Notebook", "UI/MinimapButton",
                 "Core/Sounds", "UI/Options", "UI/Follow", "Core/Model", "Core/Text", "UI/Chat", "Core/Locale"))

BREAKS = [
    # The API check, against what Forever answers
    ("API check: profession 0, the game's none, noted as a skill line it doesn't know", GAME,
     "    if id == 0 then\n        id = nil\n    end\n", ""),
    ("API check: the professions window's profession 0 reported", CHECK,
     "if id and id ~= 0 and #windowRead.wrong < 5 then", "if #windowRead.wrong < 5 then"),
    ("API check: made at login only when the saved data loaded", MAIN,
     'ns.On("PLAYER_LOGIN", ns.SelfCheck.AtLogin)', "local _ = ns.SelfCheck.AtLogin"),
    # What the character knows
    ("professions: an empty list believed at once, its recipes forgotten", GAME,
     "    if listed == 0 and next(c.profs) and not trustEmpty then", "    if false then"),
    ("professions: an empty list never believed, read again", SCAN,
     "if ns.book and Game.ReadProfessions(ns.db, true) then", "if ns.book and Game.ReadProfessions(ns.db) then"),
    # Saved data and the window
    ("saved data: the notebook's place kept with an anchor SetPoint doesn't take", DB,
     "finite(pos[2]) and (pos[3] == nil or POINTS[pos[3]])\n        and (pos[4] == nil or POINTS[pos[4]])", "finite(pos[2])"),
    ("notebook: the hammer silent in a fight", NOTEBOOK,
     "if not skill or ns.CombatRefused() then", "if not skill or InCombatLockdown() then"),
    # The gear: straight to the options, which hold the bug report (Ikar, 2026-11-13; a menu of both until then)
    ("gear: opens nothing", NOTEBOOK, "        ns.SafeCall(ns.Options.Toggle)", "        local _ = ns.Options"),
    ("gear: a second click doesn't close them", OPTIONS, "    if handle:IsShown() then\n        handle:Close()\n    else",
     "    if false then\n        handle:Close()\n    else"),
    ("options window: no bug report in it", OPTIONS, "            { kind = \"button\", name = L.REPORT_TITLE,",
     "            { kind = \"button\", name = L.REPORT_OPEN_TIP,"),
    # The window in the notebook's « Épuré » look (Ikar, 2026-11-13: "similaire a celle des recette")
    ("options window: Edit Mode's look", OPTIONS, "    look = \"window\",\n", ""),
    # The icon (F2, 2026-11-11): the minimap button and the bars' launcher name a file the package must hold
    ("icon: the minimap button names a file the addon doesn't have", MINIMAP,
     r'"Interface\\AddOns\\KaLiRecipe\\Media\\Icon"', r'"Interface\\AddOns\\KaLiRecipe\\Media\\Icone"'),
    # « Volume des sons » (Ikar, 2026-11-12): a share of each kit's own volume, at most full, nothing asked at 100 %,
    # 200 % by default (2026-11-13)
    ("volume: asked of the game at 100 % too", SOUNDS, "percent == 100 or", "percent == -1 or"),
    ("volume: the percentage asked alone, louder than the kit's own", SOUNDS,
     "return math.min(1, Sounds.KIT_VOLUME[kit] * math.max(0, percent) / 100)", "return math.min(1, math.max(0, percent) / 100)"),
    ("volume: more than full asked", SOUNDS,
     "return math.min(1, Sounds.KIT_VOLUME[kit] * math.max(0, percent) / 100)", "return Sounds.KIT_VOLUME[kit] * math.max(0, percent) / 100"),
    ("volume: the default back at the game's own level, barely heard", DB, "soundVolume = 200,", "soundVolume = 100,"),
    ("volume: a kit's own volume not the game's table's", SOUNDS, "[3093] = 0.3,", "[3093] = 0.4,"),
    ("volume: 0 % still plays", SOUNDS, "if not kit or percent == 0 or not preview", "if not kit or not preview"),
    ("volume: asked on the master channel, past the effects volume", SOUNDS, 'uiSoundSubType = "SFX"', 'uiSoundSubType = "Master"'),
    ("volume: asked of a game that takes none", SOUNDS, "if override and Sounds.CanSetVolume() then", "if override then"),
    ("volume: its slider shows a bare number", OPTIONS,
     '    return FormatPercentage and FormatPercentage(value / 100, true) or string.format("%d%%", value)\n',
     "    return tostring(value)\n"),
    ("volume: loading keeps any number", DB, "usedInMax = { 3, 20 }, soundVolume = { 0, 300 } }", "usedInMax = { 3, 20 } }"),
    # The options window (Ikar, 2026-11-13: "dans une fenêtre séparée", "comme dans flare")
    ("options window: over the notebook, not beside it", OPTIONS,
     "        if right + GAP + width <= UIParent:GetWidth() then", "        if false then"),
    ("options window: off the screen on the left", OPTIONS, "        elseif left - GAP - width >= 0 then",
     "        elseif true then"),
    ("options window: the sounds played as they're put back", OPTIONS,
     "                if not how then\n                    ns.Sounds.Play(kind, true)",
     "                if true then\n                    ns.Sounds.Play(kind, true)"),
    ("options window: the page's button leaves the game's options open", OPTIONS, "        pcall(panel.Close, panel, true)",
     "        local _ = panel"),
    ("options window: opens while the game asks about a change waiting", OPTIONS,
     "        if panel:IsShown() then\n            return\n        end\n", ""),
    ("options window: a size from the grip not shown in it", NOTEBOOK,
     "    Notebook.Refresh()\n    ns.SafeCall(ns.Options.Changed)\n", "    Notebook.Refresh()\n"),
    ("options window: the notebook's « Suivre » not shown in it", FOLLOW, "    ns.SafeCall(ns.Options.Changed)\n", ""),
    ("options window: « Suivre » ticked there doesn't dock", OPTIONS, "                ns.Follow.Set(value)", "                local _ = value"),
    ("options window: Escape leaves it open", OPTIONS, "    escape = true,", "    escape = false,"),
    ("options window: cancelling goes back to an older opening", OPTIONS, "    snapshotOnOpen = true,", "    snapshotOnOpen = false,"),
    # A vendor's limited stock (Ikar, 2026-11-13): stored in full, the highest seen kept, a grey clock after the name
    ("stock: not stored at the visit", SCAN, "costs = costs, stock = Scan.MerchantStock(i) }", "costs = costs }"),
    ("stock: the latest kept, not the highest", MODEL, "old.stock = ns.DB.MaxStock(old.stock, s.stock)",
     "old.stock = s.stock or old.stock"),
    ("stock: two copies merged keep the latest", DB, "    out.stock = DB.MaxStock(a.stock, b.stock)\n", ""),
    ("stock: one a file can't hold kept", DB, "    if s.stock ~= nil and not (finite(s.stock) and s.stock >= -1) then",
     "    if false then"),
    ("stock: no clock after the vendor's name", TEXT,
     "    return Text.Limited(s) and name .. \" \" .. Text.CLOCK_MARKUP or name", "    return name"),
    ("stock: no limit read as limited", TEXT, "type(s.stock) == \"number\" and s.stock >= 0",
     "type(s.stock) == \"number\" and s.stock >= -1"),
    ("stock: the chat line without the clock", CHAT,
     "return ns.Text.Limited(s) and link(spell) .. \" \" .. ns.Text.CLOCK_MARKUP or link(spell)", "return link(spell)"),
    ("stock: the visit's line not told which sighting", SCAN, "visit:Add(spell, what, s)", "visit:Add(spell, what)"),
    # The languages (2026-11-13: German and Spanish): every English string, with English's blanks in English's order
    ("languages: a Spanish string's blanks in another order", LOCALE, 'ALT_HAS = "%s tiene %d (%s)",',
     'ALT_HAS = "%d tiene %s (%s)",'),
    ("languages: a German key misspelt", LOCALE, 'OPT_MINIMAP_LOCK = "Position sperren",',
     'OPT_MINIMAP_LOK = "Position sperren",'),
    ("languages: a Mexican string the same as Castilian's", LOCALE,
     'PLACE_WAYPOINT = "Poner un marcador de mapa",', 'PLACE_WAYPOINT = "Poner una marca de mapa",'),
    ("languages: a German profession's name left out", "recipe/addon/KaLiRecipe/Data/Recipes.lua",
     '        [185] = "Kochkunst",\n', ""),
]
