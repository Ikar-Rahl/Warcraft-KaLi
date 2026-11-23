-- KaLi HUD's saved data: loading, repairs, and what goes before saving. Fresh tables only.
local T = KaLiHUDTests
local DB = KaLiHUDDev.ns.DB

T.Add("db", "no saved data: defaults read through, nothing written", function()
    local db, info = DB.Open(nil)
    T.True(info.firstRun, "first run")
    T.Eq(db.options.statusLeft, "xp", "default read")
    T.Eq(rawget(db.options, "statusLeft"), nil, "not written")
    T.Eq(db.version, DB.VERSION, "version")
end)

T.Add("db", "a newer version is refused and left as it is", function()
    local saved = { version = DB.VERSION + 1, pins = { rowL1 = "X" } }
    local db, why = DB.Open(saved)
    T.Eq(db, nil, "refused")
    T.True(tostring(why):find("version", 1, true), "says why")
    T.Eq(saved.pins.rowL1, "X", "untouched")
    T.Eq(DB.Open("nonsense"), nil, "not a table")
    T.Eq(DB.Open({ version = 0 / 0 }), nil, "no version")
end)

T.Add("db", "wrong values are put right, unknown ones kept", function()
    local saved = {
        version = 1,
        options = { statusLeft = "rainbow", plate = "yes", reach = 900, future = 3 },
        pins = { rowL1 = 5, rowR1 = "MultiBarRight" },
        items = { a = 3, b = { side = "up" }, c = { side = "left", order = 2 } },
        gold = { x = { money = 0 / 0 }, y = { money = 5 } },
    }
    local db, info = DB.Open(saved)
    T.Eq(rawget(db.options, "statusLeft"), nil, "a choice it doesn't have")
    T.Eq(db.options.statusLeft, "xp", "back to the default")
    T.Eq(rawget(db.options, "plate"), nil, "the wrong type")
    T.Eq(rawget(db.options, "reach"), nil, "a reach past the most")
    T.Eq(db.options.future, 3, "an option of a later version")
    T.Eq(db.pins.rowL1, 5, "an earlier build's pins, left unread")
    T.Eq(db.items.a, nil, "an item that isn't a table")
    T.Eq(db.items.b, nil, "an item on no side")
    T.Eq(db.items.c.order, 2, "an item")
    T.Eq(db.gold.x, nil, "gold that isn't a number")
    T.Eq(db.gold.y.money, 5, "gold")
    T.Eq(info.fixed, 6, "repairs counted")
    T.Eq(DB.Open({ version = 1 }).items ~= nil, true, "missing tables made")
end)

T.Add("db", "the reach and component margins validate against their ranges", function()
    for _, bad in ipairs({ -1, 0 / 0, 1 / 0, "40" }) do
        local db = DB.Open({ version = 1, options = { reach = bad, marginBars = -5, statusLeftTexture = "neon" } })
        T.Eq(rawget(db.options, "reach"), nil, "refused: " .. tostring(bad))
        T.Eq(rawget(db.options, "marginBars"), nil, "out-of-range margin reset")
        T.Eq(rawget(db.options, "statusLeftTexture"), nil, "unknown texture reset")
    end
    local ok = DB.Open({
        version = 1,
        options = { reach = 25, bridge = 70, marginBars = 14, minimapDielScale = 110, statusLeftTexture = "striped" },
        items = {
            a = { side = "ring", order = 10, angle = 215, show = "hover" },
            b = { side = "pocketLeft", order = 20, show = "always", slot = 3 },
            badSlot = { side = "pocketRight", slot = 2.5 },
            badAngle = { side = "ring", angle = 720 },
            badShow = { side = "ring", show = "blink" },
        },
    })
    T.Eq(ok.options.reach, 25, "reach kept")
    T.Eq(ok.options.bridge, 70, "bridge kept")
    T.Eq(ok.options.marginBars, 14, "marginBars kept")
    T.Eq(ok.options.minimapDielScale, 110, "minimapDielScale kept")
    T.Eq(ok.options.statusLeftTexture, "striped", "statusLeftTexture kept")
    T.Eq(ok.items.a and ok.items.a.angle, 215, "ring angle kept")
    T.Eq(ok.items.b and ok.items.b.side, "pocketLeft", "pocket side kept")
    T.Eq(ok.items.b and ok.items.b.slot, 3, "a pocket's place kept")
    T.True(ok.items.badSlot and ok.items.badSlot.side == "pocketRight" and ok.items.badSlot.slot == nil,
        "a pocket's place that can't be: the item kept, the place gone")
    T.Eq(ok.items.badAngle, nil, "out-of-range angle repaired")
    T.Eq(ok.items.badShow, nil, "unknown show mode repaired")
    T.Eq(DB.Open(nil).options.reach, 40, "the default")
end)

T.Add("db", "borders and backgrounds: sizes up to 100 %, materials, colours as \"rrggbb\"", function()
    local db = DB.Open({ version = 1, options = { borderSize = 150, bgAlpha = -1, bgIntensity = 101,
        borderColor = "auto", bgColor = "red", bgStyle = "brushed", cornerStyle = "chamfer" },
        items = { back = { side = "hidden", last = "left" }, lost = { side = "hidden", last = "attic" } } })
    for _, key in ipairs({ "borderSize", "bgAlpha", "bgIntensity", "borderColor", "bgColor", "bgStyle", "cornerStyle" }) do
        T.Eq(rawget(db.options, key), nil, key .. " repaired")
    end
    T.Eq(db.items.back and db.items.back.last, "left", "a hidden item's way back kept")
    T.Eq(db.items.lost, nil, "a way back to no side repaired")
    local ok = DB.Open({ version = 1, options = { borderStyle = "forever", borderSize = 50, bgAlpha = 60, bgIntensity = 0,
        borderColor = "f4a878", bgColor = "1A2b3c", bgStyle = "leather", infoFontSize = 14, cornerStyle = "bevel" } })
    T.Eq(ok.options.borderStyle, "forever", "an earlier build's option stays, unread")
    T.Eq(ok.options.borderSize, 50, "half the border kept")
    T.Eq(ok.options.cornerStyle, "bevel", "bevelled corners kept")
    T.Eq(ok.options.borderColor, "f4a878", "the border's colour kept")
    T.Eq(ok.options.bgColor, "1A2b3c", "a colour kept")
    T.Eq(ok.options.bgStyle, "leather", "material kept")
    T.Eq(ok.options.bgIntensity, 0, "no depth kept")
    T.Eq(ok.options.infoSize, 14, "the text size kept, now the info bar's size")
    T.Eq(rawget(ok.options, "infoFontSize"), nil, "the old text size gone")
    local fresh = DB.Open(nil).options
    T.Eq(fresh.borderColor, KaLiHUDDev.ns.Border.COLORS[1], "the border's colour defaults to its list's first")
    T.Eq(fresh.bgColor, KaLiHUDDev.ns.Border.BG_COLORS[1], "the background's colour defaults to its list's first")
    for _, style in ipairs(KaLiHUDDev.ns.Border.STYLES) do
        local m = KaLiHUDDev.ns.MATERIALS[style]
        T.True(DB.CHOICES.bgStyle[style] and (style == "smooth") == (m == nil), style .. ": a choice, a material unless smooth")
        T.True(m == nil or ((m.atlas or m.file) and m.lum > 0 and m.lum < 1), style .. ": a texture and its light")
    end
end)

T.Add("db", "what was tried, baked in or dropped, and the recesses' darkness: no such option, a saved one gone", function()
    local gone = { "borderProfile", "borderPolish", "borderNotches", "light", "innerShade", "innerShadeAlpha",
        "innerLine", "slotWells", "emptySlotAlpha", "slotRecess", "clock24", "clockServer" }
    local fresh, saved = DB.Open(nil).options, {}
    for _, key in ipairs(gone) do
        T.Eq(fresh[key], nil, key .. ": no default")
        saved[key] = DB.DEFAULTS[key] == nil and 1 or nil
    end
    local opened = DB.Open({ version = 1, options = saved }).options
    for _, key in ipairs(gone) do
        T.Eq(rawget(opened, key), nil, key .. ": what a game saved of it goes")
    end
end)

T.Add("db", "the folds' animation on or off, and sounds: none or the lists' own kept, anything else put right", function()
    local ns = KaLiHUDDev.ns
    local ok = DB.Open({ version = 1, options = { foldAnim = false, foldSound = "parchment", folderSound = "bag" } })
    T.Eq(ok.options.foldAnim, false, "no animation kept")
    T.Eq(ok.options.foldSound, "parchment", "a fold's sound kept")
    T.Eq(ok.options.folderSound, "bag", "a folder's sound kept")
    local wrong = DB.Open({ version = 1, options = { foldAnim = 2, foldSound = "submenu", folderSound = "tome" } })
    for _, key in ipairs({ "foldAnim", "foldSound", "folderSound" }) do
        T.Eq(rawget(wrong.options, key), nil, key .. " repaired")
    end
    -- the list it was until 2026-11-18 (Ikar: "remove the non darkening folding, replace the list with a checkbox"):
    -- none off, either blind on
    for was, now in pairs({ none = false, blind = true, shade = true }) do
        T.Eq(DB.Open({ version = 1, options = { foldAnim = was } }).options.foldAnim, now, was .. " as on or off")
    end
    T.Eq(DB.CHOICES.foldAnim, nil, "no list of animations")
    for _, list in ipairs({ { "foldSound", ns.FOLD_SOUNDS, ns.FOLD_SOUND_ORDER },
        { "folderSound", ns.FOLDER_SOUNDS, ns.FOLDER_SOUND_ORDER } }) do
        local key, sounds, order = list[1], list[2], list[3]
        local count = 0
        for _ in pairs(sounds) do
            count = count + 1
        end
        T.True(DB.CHOICES[key].none and count == #order, key .. ": none, and each sound once in the list's order")
        for _, id in ipairs(order) do
            T.True(sounds[id] and DB.CHOICES[key][id], key .. ": " .. id .. " a choice")
        end
    end
end)

T.Add("db", "Ikar's defaults, the Blizzard style's look; an automatic status bar and the info bar's three sizes from before", function()
    local o = DB.Open(nil).options
    local want = { borderSize = 65, borderAlpha = 75, borderColor = "c4977c", bgStyle = "stone", bgIntensity = 50,
        bgColor = "4a3a2a", bgAlpha = 90, foldArt = "bronze1", cornerStyle = "round", preset = "blizzard", marginBars = 7, padBars = 1, marginBags = 7, marginStatus = 7,
        minimapRing = "blizzard", infoSize = 10, infoSpacing = 10, statusLeft = "xp", statusRight = "rep",
        foldAnim = true }
    for key, v in pairs(want) do
        T.Eq(o[key], v, key)
    end
    for _, gone in ipairs({ "recessShadow", "recessLight", "collapsibleBags", "infoHeight", "infoFontSize",
        "infoIconSize" }) do
        T.Eq(DB.DEFAULTS[gone], nil, gone .. " no longer an option")
    end
    T.Eq(DB.CHOICES.statusLeft.auto, nil, "no automatic bar")
    local db, info = DB.Open({ version = 1, items = {}, gold = {}, options = { statusLeft = "auto",
        statusRight = "auto", infoHeight = 18, infoFontSize = 12, infoIconSize = 14 } })
    T.Eq(rawget(db.options, "statusLeft"), nil, "an automatic bar back to its default")
    T.Eq(db.options.infoSize, 12, "the text size the info bar had, its size")
    for _, gone in ipairs({ "infoHeight", "infoFontSize", "infoIconSize" }) do
        T.Eq(rawget(db.options, gone), nil, gone .. " gone")
    end
    T.Eq(info.fixed, 2, "the automatic bars put right, the sizes carried over")
    local kept = DB.Open({ version = 1, options = { infoSize = 8, infoFontSize = 16 } })
    T.Eq(kept.options.infoSize, 8, "a size set already wins over an old text size")
end)

T.Add("db", "the status bars' places: left or right, where they were let go and how wide", function()
    local db, info = DB.Open({ version = 1, options = {}, items = {}, gold = {},
        statusPlaces = { left = { x = 700, y = 200, w = 380 }, right = { x = 0 / 0, y = 1, w = 2 },
            middle = { x = 1, y = 1, w = 1 }, [1] = "up" } })
    T.Eq(db.statusPlaces.left and db.statusPlaces.left.w, 380, "a place kept")
    T.Eq(db.statusPlaces.right, nil, "a place that isn't a number")
    T.Eq(db.statusPlaces.middle, nil, "a bar there isn't")
    T.Eq(db.statusPlaces[1], nil, "a place that isn't a table")
    T.Eq(info.fixed, 3, "repairs counted")
    T.Eq(next(DB.Open({ version = 1 }).statusPlaces), nil, "a file from before them: none")
end)

T.Add("db", "each character's frozen plate: its screen's size and its frames, a broken frame or plate gone", function()
    local good = { key = "MainActionBar", x = 540, y = 45, w = 401, h = 39 }
    local db, info = DB.Open({ version = 1, options = {}, items = {}, gold = {}, plates = {
        ["Realm-Ikar"] = { W = 2100.5, H = 1181.5, t = 1794774089, frames = { good, { key = "ChatFrame1", x = 0 / 0, y = 1,
            w = 1, h = 1 }, "up" } },
        ["Realm-Alt"] = { W = "wide", H = 1, frames = {} },
        [7] = { W = 1, H = 1, frames = {} },
    } })
    local p = db.plates["Realm-Ikar"]
    T.True(p and #p.frames == 1 and p.frames[1] == good and p.W == 2100.5, "a plate kept, its good frames with it")
    T.Eq(db.plates["Realm-Alt"], nil, "a plate without a screen's size")
    T.Eq(db.plates[7], nil, "a plate under no character")
    T.Eq(info.fixed, 4, "repairs counted")
    T.Eq(next(DB.Open({ version = 1 }).plates), nil, "a file from before them: none")
end)

T.Add("db", "a setting both status bars shared before goes to each bar that has none, and is gone", function()
    local db, info = DB.Open({ version = 1, items = {}, gold = {}, options = { statusFontSize = 8,
        statusNumbers = "remaining", statusRightNumbers = "percent", statusTicks = false, statusHeight = 8 } })
    local o = db.options
    T.Eq(o.statusLeftFontSize, 8, "the left bar's size")
    T.Eq(o.statusRightFontSize, 8, "the right bar's size")
    T.Eq(o.statusLeftNumbers, "remaining", "the left bar's numbers")
    T.Eq(o.statusRightNumbers, "percent", "a bar's own kept")
    T.Eq(o.statusRightTicks, false, "no bubbles on the right bar either")
    T.Eq(rawget(o, "statusFontSize"), nil, "the shared size gone")
    T.Eq(rawget(o, "statusNumbers"), nil, "the shared numbers gone")
    T.Eq(info.fixed, 0, "nothing to put right")
    T.Eq(o.statusHeight, 8, "an earlier build's option stays, unread")
    local wrong = { statusLeftTexture = "neon", statusRightText = "blink", statusLeftNumbers = "roman",
        statusRightTicks = "no", statusLeftWidth = 5000, statusRightWidth = -1, statusLeftFontSize = 2,
        statusRightFontSize = 40 }
    local copy = {}
    for key, v in pairs(wrong) do
        copy[key] = v
    end
    local bad, badInfo = DB.Open({ version = 1, items = {}, gold = {}, options = copy })
    for key in pairs(wrong) do
        T.Eq(rawget(bad.options, key), nil, key .. " saved wrong, put right")
    end
    T.Eq(badInfo.fixed, 8, "each repair counted")
end)

T.Add("db", "before saving, defaults and numbers a file can't hold go", function()
    local db = DB.Open(nil)
    db.options.plate = true
    db.options.statusLeftText = "always"
    db.gold.z = { money = 1, t = 0 / 0 }
    DB.BeforeSave(db)
    T.Eq(rawget(db.options, "plate"), nil, "a default")
    T.Eq(db.options.statusLeftText, "always", "a change")
    T.Eq(db.gold.z.t, nil, "nan")
    T.Eq(db.gold.z.money, 1, "the rest")
end)

T.Add("db", "folders: their settings put right, an item in a folder gone back to its default", function()
    local icon = KaLiHUDDev.ns.ICONS[2][1]
    local db, info = DB.Open({
        version = 1,
        options = {},
        gold = {},
        folders = {
            KaLiHUD_Folder1 = { name = "Outils", style = "grid", perLine = 40, dir = "upleft", opened = "yes",
                icon = icon, iconOnly = true },
            KaLiHUD_Folder2 = { name = "" },
            KaLiHUD_Folder3 = 5,
            KaLiHUD_Folder4 = { name = "Sacs", icon = "INV_Misc_Bag_08", iconOnly = 1 },
        },
        items = {
            a = { side = "folder", folder = "KaLiHUD_Folder1", order = 10 },
            b = { side = "folder", folder = "nowhere" },
            c = { side = "hidden", last = "folder", folder = "KaLiHUD_Folder1" },
        },
        buttonsLeft = { X = true, Y = "no" },
    })
    local f = db.folders.KaLiHUD_Folder1
    T.Eq(f and f.name, "Outils", "a folder kept")
    T.Eq(f and f.style, nil, "a style it doesn't have")
    T.Eq(f and f.perLine, nil, "too many a line")
    T.Eq(f and f.dir, "upleft", "its direction kept")
    T.Eq(f and f.opened, nil, "open, not true")
    T.Eq(f and f.icon, icon, "an icon of the library")
    T.Eq(f and f.iconOnly, true, "its icon alone")
    local bags = db.folders.KaLiHUD_Folder4
    T.Eq(bags and bags.icon, nil, "an icon the library hasn't")
    T.Eq(bags and bags.iconOnly, nil, "its icon alone, not true")
    T.Eq(db.folders.KaLiHUD_Folder2, nil, "a folder without a name")
    T.Eq(db.folders.KaLiHUD_Folder3, nil, "a folder that isn't a table")
    T.Eq(db.items.a and db.items.a.folder, "KaLiHUD_Folder1", "an item in a folder")
    T.Eq(db.items.b, nil, "an item in a folder that isn't")
    T.Eq(db.items.c and db.items.c.last, "folder", "a hidden item's way back into its folder")
    T.Eq(db.buttonsLeft.X, true, "a button left to its addon")
    T.Eq(db.buttonsLeft.Y, nil, "a wrong one")
    T.Eq(info.fixed, 9, "repairs counted")
end)

-- The review of 2026-11-18: a folder saved under another key had a plain button where its code takes a secure one
-- for granted, and raised an error at every layout.
T.Add("db", "what the hub makes is saved under its kind's id: a folder, a macro or a separator under another key goes", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        gold = {},
        folders = { KaLiHUD_Folder1 = { name = "Un" }, Outils = { name = "Outils" }, KaLiHUD_Folder = { name = "Sans numéro" },
            KaLiHUD_Macro2 = { name = "Un autre genre" } },
        macros = { KaLiHUD_Macro1 = { name = "Danse", text = "/dance" }, Danse = { name = "Danse", text = "/dance" } },
        separators = { KaLiHUD_Separator1 = true, trait = true },
        items = {
            Outils = { side = "right", order = 1 },
            dedans = { side = "folder", folder = "Outils", order = 10 },
            KaLiHUD_Separator1 = { side = "folder", folder = "KaLiHUD_Folder1", order = 10 },
            trait = { side = "folder", folder = "KaLiHUD_Folder1", order = 20 },
        },
    })
    T.Eq(db.folders.KaLiHUD_Folder1 and db.folders.KaLiHUD_Folder1.name, "Un", "a folder under its id kept")
    T.Eq(db.folders.Outils, nil, "a folder under a name")
    T.Eq(db.folders.KaLiHUD_Folder, nil, "a folder under its prefix with no number")
    T.Eq(db.folders.KaLiHUD_Macro2, nil, "a folder under a macro's id")
    T.Eq(db.items.dedans, nil, "what stood in the folder that went")
    T.Eq(db.macros.KaLiHUD_Macro1 and db.macros.KaLiHUD_Macro1.text, "/dance", "a macro under its id kept")
    T.Eq(db.macros.Danse, nil, "a macro under a name")
    T.Eq(db.separators.KaLiHUD_Separator1, true, "a separator under its id kept")
    T.Eq(db.separators.trait, nil, "a separator under a name")
    T.Eq(info.fixed, 6, "repairs counted")
end)

T.Add("db", "folders: one in another kept; one in itself, or a ring of them broken at its first, back by default", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        gold = {},
        folders = {
            KaLiHUD_Folder1 = { name = "Un" }, KaLiHUD_Folder2 = { name = "Deux" }, KaLiHUD_Folder3 = { name = "Trois" },
            KaLiHUD_Folder4 = { name = "Quatre" }, KaLiHUD_Folder5 = { name = "Cinq" },
        },
        items = {
            KaLiHUD_Folder1 = { side = "folder", folder = "KaLiHUD_Folder2", order = 10 },
            KaLiHUD_Folder2 = { side = "folder", folder = "KaLiHUD_Folder3", order = 10 },
            KaLiHUD_Folder3 = { side = "folder", folder = "KaLiHUD_Folder1", order = 10 },
            KaLiHUD_Folder4 = { side = "folder", folder = "KaLiHUD_Folder4", order = 10 },
            KaLiHUD_Folder5 = { side = "folder", folder = "KaLiHUD_Folder2", order = 20 },
        },
    })
    T.Eq(db.items.KaLiHUD_Folder1, nil, "the first of a ring back where it goes by default")
    T.Eq(db.items.KaLiHUD_Folder2 and db.items.KaLiHUD_Folder2.folder, "KaLiHUD_Folder3", "the ring's next kept")
    T.Eq(db.items.KaLiHUD_Folder3 and db.items.KaLiHUD_Folder3.folder, "KaLiHUD_Folder1", "the ring's last kept")
    T.Eq(db.items.KaLiHUD_Folder4, nil, "a folder in itself")
    T.Eq(db.items.KaLiHUD_Folder5 and db.items.KaLiHUD_Folder5.folder, "KaLiHUD_Folder2", "a folder in another")
    T.Eq(info.fixed, 2, "repairs counted")
end)

-- The review of 2026-11-17: a key that wasn't a name reached the code that reads names and stopped the first setup.
T.Add("db", "an element's key is its name: one that isn't a text goes, the rest kept; a folder for what doesn't fit", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        gold = {},
        folders = {
            KaLiHUD_Folder1 = { name = "Suite", role = "overflow", overflow = true },
            KaLiHUD_Folder2 = { name = "Autre", overflow = "yes" },
        },
        items = {
            [42] = { side = "right" },
            [true] = { side = "left" },
            Gold = { side = "left", order = 10 },
        },
        buttonsLeft = { [7] = true, SomeButton = true },
    })
    T.Eq(db.items[42], nil, "an item under a number")
    T.Eq(db.items[true], nil, "an item under a boolean")
    T.Eq(db.items.Gold and db.items.Gold.side, "left", "an item under its name kept")
    T.Eq(db.buttonsLeft[7], nil, "a button left under a number")
    T.Eq(db.buttonsLeft.SomeButton, true, "a button left under its name kept")
    T.Eq(db.folders.KaLiHUD_Folder1 and db.folders.KaLiHUD_Folder1.overflow, true, "the folder for what doesn't fit kept")
    T.Eq(db.folders.KaLiHUD_Folder1 and db.folders.KaLiHUD_Folder1.role, "overflow", "its role kept")
    T.Eq(db.folders.KaLiHUD_Folder2 and db.folders.KaLiHUD_Folder2.overflow, nil, "one said so otherwise than true")
    T.Eq(db.folders.KaLiHUD_Folder2 and db.folders.KaLiHUD_Folder2.name, "Autre", "that folder kept")
    T.Eq(info.fixed, 4, "repairs counted")
end)

T.Add("db", "an element's look on the bar: its icon and its text, its icon alone or its text alone; any other gone, the element kept", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        gold = {},
        items = {
            Gold = { side = "left", order = 10, look = "text" },
            Bags = { side = "left", order = 20, look = "icon" },
            Launcher = { side = "right", order = 10, look = "both" },
            Odd = { side = "right", order = 20, look = "wide" },
            Truthy = { side = "right", order = 30, look = true },
        },
    })
    T.Eq(db.items.Gold.look, "text", "its text alone kept")
    T.Eq(db.items.Bags.look, "icon", "its icon alone kept")
    T.Eq(db.items.Launcher.look, "both", "both kept")
    T.Eq(db.items.Odd and db.items.Odd.look, nil, "a look that isn't one goes")
    T.Eq(db.items.Odd and db.items.Odd.order, 20, "that element kept where it stands")
    T.Eq(db.items.Truthy and db.items.Truthy.look, nil, "nor is true one")
    T.Eq(info.fixed, 2, "repairs counted")
end)

T.Add("db", "a folder's and a macro's look: its icon alone or its name alone, true, never both", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        items = {},
        gold = {},
        folders = {
            KaLiHUD_Folder1 = { name = "Un", nameOnly = true },
            KaLiHUD_Folder2 = { name = "Deux", iconOnly = true, nameOnly = true },
        },
        macros = {
            KaLiHUD_Macro1 = { name = "Salut", text = "/wave", nameOnly = true },
            KaLiHUD_Macro2 = { name = "Danse", text = "/dance", iconOnly = 1, nameOnly = "yes" },
            KaLiHUD_Macro3 = { name = "Rire", text = "/lol", iconOnly = true, nameOnly = true },
        },
    })
    T.Eq(db.folders.KaLiHUD_Folder1.nameOnly, true, "a folder's name alone")
    T.Eq(db.folders.KaLiHUD_Folder2.iconOnly, true, "both: its icon alone kept")
    T.Eq(db.folders.KaLiHUD_Folder2.nameOnly, nil, "both: its name alone gone")
    T.Eq(db.macros.KaLiHUD_Macro1.nameOnly, true, "a macro's name alone")
    T.Eq(db.macros.KaLiHUD_Macro2.iconOnly, nil, "not true: gone")
    T.Eq(db.macros.KaLiHUD_Macro2.nameOnly, nil, "not true: gone")
    T.Eq(db.macros.KaLiHUD_Macro3.nameOnly, nil, "a macro's both: its name alone gone")
    T.Eq(info.fixed, 4, "repairs counted")
end)

T.Add("db", "macros: a name, a library icon, their own commands or a game macro's name; what was made once kept", function()
    local icon = KaLiHUDDev.ns.ICONS[2][1]
    local db, info = DB.Open({
        version = 1,
        options = {},
        items = {},
        gold = {},
        macros = {
            KaLiHUD_Macro1 = { name = "Salut", icon = icon, text = "/wave" },
            KaLiHUD_Macro2 = { name = "Monture", macro = "Monture", icon = "INV_Misc_Bag_08" },
            KaLiHUD_Macro3 = { name = "" },
            KaLiHUD_Macro4 = { name = "Longue", text = string.rep("a", DB.MACRO_BYTES + 1), macro = 7 },
            KaLiHUD_Macro5 = "x",
        },
        seeds = { emote = true, other = "yes" },
    })
    local m1, m2, m4 = db.macros.KaLiHUD_Macro1, db.macros.KaLiHUD_Macro2, db.macros.KaLiHUD_Macro4
    T.Eq(m1 and m1.text, "/wave", "its own commands")
    T.Eq(m1 and m1.icon, icon, "an icon of the library")
    T.Eq(m2 and m2.macro, "Monture", "a game macro's name")
    T.Eq(m2 and m2.icon, nil, "an icon the library hasn't")
    T.Eq(db.macros.KaLiHUD_Macro3, nil, "a macro without a name")
    T.Eq(db.macros.KaLiHUD_Macro5, nil, "a macro that isn't a table")
    T.Eq(m4 and m4.name, "Longue", "a macro kept with its fields put right")
    T.Eq(m4 and m4.text, nil, "commands longer than the game's macros")
    T.Eq(m4 and m4.macro, nil, "a game macro's name that isn't text")
    T.Eq(db.seeds.emote, true, "what was made once")
    T.Eq(db.seeds.other, nil, "a seed that isn't true")
    T.Eq(info.fixed, 6, "repairs counted")
    local fresh = DB.Open(nil)
    T.True(type(fresh.macros) == "table" and type(fresh.seeds) == "table", "a first run: no macros, nothing made yet")
    local older = DB.Open({ version = 1 })
    T.True(type(older.macros) == "table" and next(older.macros) == nil, "a file from before macros: none")
end)

-- A macro's own right-click and its own tooltip (Ikar 2026-11-17): text, the right-click as long as its commands, the
-- tooltip as a note's; one that can't be goes, the macro kept.
T.Add("db", "macros: a right-click's commands and a tooltip of its own; one that can't be gone, the macro kept", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        items = {},
        gold = {},
        macros = {
            KaLiHUD_Macro1 = { name = "Danse", text = "/dance", right = "/sit", tip = "S'asseoir" },
            KaLiHUD_Macro2 = { name = "Trop", text = "/dance", right = string.rep("a", DB.MACRO_BYTES + 1),
                tip = string.rep("b", DB.NOTE_BYTES + 1) },
            KaLiHUD_Macro3 = { name = "Faux", right = 7, tip = "" },
        },
    })
    local m1, m2, m3 = db.macros.KaLiHUD_Macro1, db.macros.KaLiHUD_Macro2, db.macros.KaLiHUD_Macro3
    T.Eq(m1 and m1.right, "/sit", "a right-click's commands")
    T.Eq(m1 and m1.tip, "S'asseoir", "a tooltip of its own")
    T.Eq(m2 and m2.right, nil, "a right-click longer than a macro's commands")
    T.Eq(m2 and m2.tip, nil, "a tooltip longer than a note's text")
    T.Eq(m2 and m2.text, "/dance", "the macro kept, its commands too")
    T.Eq(m3 and m3.right, nil, "a right-click that isn't text")
    T.Eq(m3 and m3.tip, nil, "an empty tooltip")
    T.Eq(info.fixed, 4, "repairs counted")
end)

-- A description for each of its buttons (Ikar 2026-11-18: "Add Description to the macro right and left button...
-- Single line enty, short"): a line of text, as short as DB.DESC_BYTES; one that can't be goes, the macro kept.
T.Add("db", "macros: each button's description, one short line; one that can't be gone, the macro kept", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        items = {},
        gold = {},
        macros = {
            KaLiHUD_Macro1 = { name = "Danse", text = "/dance", leftDesc = "Danser", rightDesc = "S'asseoir" },
            KaLiHUD_Macro2 = { name = "Faux", text = "/wave", leftDesc = "Deux\nlignes",
                rightDesc = string.rep("a", DB.DESC_BYTES + 1) },
            KaLiHUD_Macro3 = { name = "Vide", leftDesc = " ", rightDesc = 7 },
        },
    })
    local m1, m2, m3 = db.macros.KaLiHUD_Macro1, db.macros.KaLiHUD_Macro2, db.macros.KaLiHUD_Macro3
    T.Eq(m1 and m1.leftDesc, "Danser", "the left button's description")
    T.Eq(m1 and m1.rightDesc, "S'asseoir", "the right button's description")
    T.Eq(m2 and m2.leftDesc, nil, "a description over two lines")
    T.Eq(m2 and m2.rightDesc, nil, "a description too long")
    T.Eq(m2 and m2.text, "/wave", "the macro kept, its commands too")
    T.Eq(m3 and m3.leftDesc, nil, "a description of blanks")
    T.Eq(m3 and m3.rightDesc, nil, "a description that isn't text")
    T.Eq(info.fixed, 4, "repairs counted")
end)

-- One made by KaLi HUD for a folder (UI/Hub/Seeds.lua): its seed, "<role>:<key>", up to a name's length.
T.Add("db", "macros: one made for a folder kept as such; a seed that can't be gone, the macro kept", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        items = {},
        gold = {},
        macros = {
            KaLiHUD_Macro1 = { name = "/salut", text = "/salut", seed = "emotes:emote-WAVE" },
            KaLiHUD_Macro2 = { name = "Sans rôle", seed = "reload" },
            KaLiHUD_Macro3 = { name = "Nombre", seed = 3 },
            KaLiHUD_Macro4 = { name = "Long", seed = "x:" .. string.rep("a", DB.NAME_BYTES) },
        },
    })
    local m = db.macros
    T.Eq(m.KaLiHUD_Macro1 and m.KaLiHUD_Macro1.seed, "emotes:emote-WAVE", "a seed with its role")
    T.Eq(m.KaLiHUD_Macro2 and m.KaLiHUD_Macro2.seed, nil, "a seed without its role")
    T.Eq(m.KaLiHUD_Macro3 and m.KaLiHUD_Macro3.seed, nil, "a seed that isn't text")
    T.Eq(m.KaLiHUD_Macro4 and m.KaLiHUD_Macro4.seed, nil, "a seed longer than a name")
    T.Eq(m.KaLiHUD_Macro4 and m.KaLiHUD_Macro4.name, "Long", "the macro kept, its seed gone")
    T.Eq(info.fixed, 3, "repairs counted")
end)

T.Add("db", "separators in folders, a folder's role, a note's longer text", function()
    local db, info = DB.Open({
        version = 1,
        options = {},
        gold = {},
        folders = {
            KaLiHUD_Folder1 = { name = "Armes", role = "weapons" },
            KaLiHUD_Folder2 = { name = "Autre", role = 12 },
        },
        items = {
            KaLiHUD_Separator1 = { side = "folder", folder = "KaLiHUD_Folder1", order = 20 },
            KaLiHUD_Separator2 = { side = "right", order = 5 },
        },
        separators = { KaLiHUD_Separator1 = true, KaLiHUD_Separator2 = true, KaLiHUD_Separator3 = true,
            KaLiHUD_Separator4 = "yes" },
        macros = {
            KaLiHUD_Macro1 = { name = "Courses", note = true, text = string.rep("a", DB.MACRO_BYTES + 10) },
            KaLiHUD_Macro2 = { name = "Bizarre", note = 1, text = "/wave" },
            KaLiHUD_Macro3 = { name = "Trop longue", note = true, text = string.rep("a", DB.NOTE_BYTES + 1) },
        },
    })
    T.Eq(db.folders.KaLiHUD_Folder1.role, "weapons", "a folder's role")
    T.Eq(db.folders.KaLiHUD_Folder2.role, nil, "a role that isn't text")
    T.Eq(db.separators.KaLiHUD_Separator1, true, "a separator in a folder")
    T.Eq(db.separators.KaLiHUD_Separator2, nil, "a separator on the bar")
    T.Eq(db.separators.KaLiHUD_Separator3, nil, "a separator standing nowhere")
    T.Eq(db.separators.KaLiHUD_Separator4, nil, "a separator that isn't true")
    T.Eq(db.macros.KaLiHUD_Macro1 and #db.macros.KaLiHUD_Macro1.text, DB.MACRO_BYTES + 10, "a note longer than a macro")
    T.Eq(db.macros.KaLiHUD_Macro2 and db.macros.KaLiHUD_Macro2.note, nil, "a note's mark that isn't true")
    T.Eq(db.macros.KaLiHUD_Macro3 and db.macros.KaLiHUD_Macro3.text, nil, "a note's text too long")
    T.Eq(info.fixed, 6, "repairs counted")
    local older = DB.Open({ version = 1 })
    T.True(type(older.separators) == "table" and next(older.separators) == nil, "a file from before separators: none")
end)

T.Add("db", "the game's settings the HUD turned off: the player's value kept, anything else dropped", function()
    local db, info = DB.Open({ version = 1, cvars = { minimapShowPlayerCoords = "1", rotateMinimap = "1", other = 2 } })
    T.Eq(db.cvars.minimapShowPlayerCoords, "1", "the coordinates' setting as the player had it")
    T.Eq(db.cvars.rotateMinimap, nil, "a setting the HUD doesn't turn off")
    local _, base = DB.Open({ version = 1, cvars = {} })
    T.Eq(info.fixed - base.fixed, 2, "repairs counted")
    local older = DB.Open({ version = 1 })
    T.True(type(older.cvars) == "table" and next(older.cvars) == nil, "a file from before: none kept")
end)
