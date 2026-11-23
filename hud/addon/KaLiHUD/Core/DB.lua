-- Saved data, account-wide (KaLiHUDDB): the options, where each info bar item shows, the folders, the macros, other
-- addons' minimap buttons left to them, where the status bars were dragged in Edit Mode, each character's gold for the
-- gold item, each character's plate as frozen leaving Edit Mode (UI/Plate.lua), and what was made once for the player
-- (`seeds`: « Suite »), so a deleted one isn't made again. And, since 2026-11-19 (Core/Sets.lua): a
-- character's own settings where it has some (`chars`), the account's set aside while such a character plays
-- (`account`, `live`), and the sets of settings kept under a name (`presets`).
-- Rules, as the family's other addons:
-- - Data from a newer version is left alone and the addon does nothing (ns.disabled).
-- - What this version doesn't know (an option, an earlier build's pins, an item's field) stays as it is, unread.
-- - A setting both status bars shared before each had its own goes to each bar not set yet.
-- - Options hold only what the player changed; defaults are read through.
local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 1
-- maxCorners at this, the slider's top: no limit
DB.UNLIMITED_CORNERS = 40

-- reach: how far above the plate, in UIParent's units, a frame may stand and still be taken.
-- bridge: the widest horizontal gap between covered pieces (or a screen edge) that closes up to its lower side.
DB.DEFAULTS = {
    -- Plate & silhouette
    plate = true, reach = 40, bridge = 40,
    corner = 8, fillet = 10, cornerStyle = ns.LOOK.corners, maxCorners = DB.UNLIMITED_CORNERS,
    footGroove = true,
    -- the minimap pockets' free places marked as small recesses while the slots are unlocked
    pocketMarks = true,
    -- Per-component margins & slot padding
    marginBars = 7, padBars = 1,
    marginBags = 7,
    marginStatus = 7,
    -- Minimap ownership & dressing
    minimap = true, minimapRing = "blizzard", minimapHeader = false,
    minimapAutoZoom = 0, minimapZoom = "off",
    -- the day/night ring round the map, % of the icon size
    minimapDielScale = 100,
    -- Unified slot hub (info bar + dome space + minimap pockets + minimap ring)
    slotsLocked = true,
    -- The KaLi border (the shipped look's, Data/Look.lua) and the background: a colour, a material imprinted into it;
    -- colours "rrggbb". Ikar's sizes and opacities (2026-11-15); the colours, the material, the map's ring, the
    -- cartouche and the corners the first style's, « Blizzard - cuivre » (Data/Presets.lua; Ikar 2026-11-17: the
    -- defaults "blizard"), the border copper where it was his dark bronze, now « Steampunk - bronze »'s.
    borderSize = 65, borderAlpha = 75, borderColor = "c4977c",
    bgStyle = "stone", bgIntensity = 50, bgColor = "4a3a2a", bgAlpha = 90,
    -- the style last applied (Data/Presets.lua): what a value the player changed since is told from
    preset = "blizzard",
    -- Windows
    cleanBarArt = true,
    windowFold = true, chatFolded = false, meterFolded = false,
    chatPeekOnType = true, meterUnfoldCombat = false,
    -- a fold animated or not (the darkening blind; the plain one gone, Ikar 2026-11-18: "remove the non darkening
    -- folding, replace the list with a checkbox") and its sound as clicked (ns.FOLD_SOUNDS' or "none")
    foldAnim = true, foldSound = "tome",
    -- what folds them: a cartouche (Data/Cartouches.lua) or "arrow", the arrow alone; lift: its flat line over its place
    foldArt = "bronze1", foldArtWidth = 50, foldArtLift = 0,
    -- Status bars, each its own settings (Ikar 2026-11-15: "make all the setting local to each bar"): its height
    -- follows its text's size; width 0: from the map's ring out to the far end of the bars above it
    statusLeft = "xp", statusRight = "rep",
    statusLeftText = "hover", statusRightText = "hover",
    statusLeftTexture = "forever", statusRightTexture = "forever",
    statusLeftTicks = true, statusRightTicks = true,
    statusLeftNumbers = "values", statusRightNumbers = "values",
    statusLeftFontSize = 11, statusRightFontSize = 11,
    statusLeftWidth = 0, statusRightWidth = 0,
    -- each bar's end cap at the map's side, its shape the corners' ("auto"); its fill towards the map unless reversed
    statusLeftCap = "right", statusRightCap = "left", statusLeftCapShape = "auto", statusRightCapShape = "auto",
    statusLeftReverse = false, statusRightReverse = false,
    -- one for both: Blizzard's and FlareUI's bars hidden while one of ours shows
    hideExternalXP = true,
    -- the mana's regeneration a second's, not in 5 s as the sheet's (Ikar 2026-11-23: "Add an option to show mana as per
    -- second in the settigns menu")
    manaPerSecond = false,
    -- Info bar & items: one size, its text's (Ikar 2026-11-15), the bar's height, the icons and the spacing following
    infoBar = true, infoSize = 10, infoSpacing = 10,
    copper = false, bagsFree = false,
    -- a folder's list opened or shut by a click: ns.FOLDER_SOUNDS' or "none"
    folderSound = "submenu",
    -- in a fight, every folder closing once the pointer has left it, one opening on a click too (Ikar 2026-11-16)
    folderCombatClose = true,
}

DB.RANGES = {
    reach = { 0, 400 },
    bridge = { 0, 400 },
    corner = { 0, 24 },
    fillet = { 0, 24 },
    maxCorners = { 0, DB.UNLIMITED_CORNERS },
    marginBars = { 0, 32 },
    padBars = { 0, 16 },
    marginBags = { 0, 32 },
    marginStatus = { 0, 24 },
    minimapAutoZoom = { 0, 20 },
    minimapDielScale = { 50, 125 },
    foldArtWidth = { 20, 100 },
    foldArtLift = { -20, 20 },
    statusLeftWidth = { 0, 1200 },
    statusRightWidth = { 0, 1200 },
    statusLeftFontSize = { 6, 16 },
    statusRightFontSize = { 6, 16 },
    infoSize = { 6, 20 },
    infoSpacing = { 6, 28 },
    borderSize = { 50, 100 },
    borderAlpha = { 0, 100 },
    bgIntensity = { 0, 100 },
    bgAlpha = { 0, 100 },
}

local SHOW_MODES = { always = true, hover = true, off = true }
local CAP_ENDS = { right = true, left = true, none = true }
local CAP_SHAPES = { auto = true, bevel = true, round = true, square = true }
local STATUS_TEXT = { hover = true, always = true }
local STATUS_TEXTURES = { forever = true, striped = true, flat = true }
local STATUS_NUMBERS = { values = true, percent = true, both = true, remaining = true }
local FOLD_ARTS = { arrow = true }
for _, id in ipairs(ns.CARTOUCHE_ORDER) do
    FOLD_ARTS[id] = true
end
-- Cartouches no longer made, each to its nearest still made: the same piece, so its lift still fits; the Steampunk 2,
-- made for an evening (2026-11-20: "keep steampunk 1, rename it to steampunk, remove the 2"), to the Steampunk's.
local RETIRED_ARTS = { complex1 = "complex1darkgold", complex2 = "complex2silver", steampunk2 = "steampunk" }
-- The map's ring: KaLi's border, Blizzard's, Blizzard's classic recess, or one of Ikar's (Data/MinimapRings.lua).
local MINIMAP_RINGS = { kali = true, blizzard = true, none = true }
-- Rings no longer made, each to the one in its place: both Steampunk ones to the one since 2026-11-20 (Ikar: "I have a
-- new steampunk minimap art that will replace the 2 currently in the plugin").
local RETIRED_RINGS = { steampunk1 = "steampunk", steampunk2 = "steampunk" }
for id in pairs(ns.MINIMAP_RINGS) do
    MINIMAP_RINGS[id] = true
end
local FOLD_SOUNDS, FOLDER_SOUNDS = { none = true }, { none = true }
for key in pairs(ns.FOLD_SOUNDS) do
    FOLD_SOUNDS[key] = true
end
for key in pairs(ns.FOLDER_SOUNDS) do
    FOLDER_SOUNDS[key] = true
end
DB.CHOICES = {
    statusLeft = { xp = true, rep = true, honor = true, none = true },
    statusRight = { xp = true, rep = true, honor = true, none = true },
    statusLeftCap = CAP_ENDS, statusRightCap = CAP_ENDS,
    statusLeftCapShape = CAP_SHAPES, statusRightCapShape = CAP_SHAPES,
    statusLeftText = STATUS_TEXT, statusRightText = STATUS_TEXT,
    statusLeftTexture = STATUS_TEXTURES, statusRightTexture = STATUS_TEXTURES,
    statusLeftNumbers = STATUS_NUMBERS, statusRightNumbers = STATUS_NUMBERS,
    minimapRing = MINIMAP_RINGS,
    minimapZoom = SHOW_MODES,
    bgStyle = { smooth = true, rock = true, stone = true, darkstone = true, marble = true, leather = true, wood = true,
        planks = true, masonry = true, parchment = true },
    cornerStyle = { round = true, square = true, bevel = true },
    foldArt = FOLD_ARTS,
    foldSound = FOLD_SOUNDS,
    folderSound = FOLDER_SOUNDS,
    preset = ns.PRESET_BY_ID,
}
-- Colours: "rrggbb".
DB.COLORS = { borderColor = true, bgColor = true }
local function isColor(v)
    return type(v) == "string" and v:match("^%x%x%x%x%x%x$") ~= nil
end
local OPTIONS = { __index = DB.DEFAULTS }

DB.SIDES = {
    left = true, free = true, centre = true, right = true,
    pocketLeft = true, pocketRight = true, ring = true,
    folder = true, hidden = true,
}
DB.SHOW_MODES = { always = true, hover = true }
-- An element's look on the bar, chosen by the player (UI/Hub/Hub.lua's SetItemLook).
DB.ITEM_LOOKS = { both = true, icon = true, text = true }
-- A folder's settings (UI/Hub/Folders.lua): what its list shows, which way it runs and opens, how it opens, the icon
-- it wears (Data/Icons.lua's).
DB.FOLDER_CHOICES = {
    style = { icons = true, text = true, names = true },
    flow = { horizontal = true, vertical = true },
    dir = { upleft = true, upright = true, downleft = true, downright = true },
    open = { click = true, leave = true, hover = true },
    icon = {},
}
for _, icon in ipairs(ns.ICONS) do
    DB.FOLDER_CHOICES.icon[icon[1]] = true
end
-- How many to a line of a folder's list: a slider up to 25 (Ikar 2026-11-20: "Ça doit être un slider avec la limite
-- max à 25"), a column of the character's attributes holding fourteen.
DB.PER_LINE = { 1, 25 }
-- What the hub makes is saved under an id, its kind's prefix and a number (UI/Hub/Hub.lua's Made): a folder, a macro
-- or a separator under any other key goes at load. A folder so saved had a plain button where its code takes a
-- secure one for granted, and raised an error at every layout (the review of 2026-11-18).
-- A copy (UI/Hub/Hub.lua's copies): one of our items shown once more, out of the locked folder it stands in.
DB.IDS = { folders = "KaLiHUD_Folder", macros = "KaLiHUD_Macro", separators = "KaLiHUD_Separator",
    copies = "KaLiHUD_Copy" }
local function isId(kind, id)
    return type(id) == "string" and id:find("^" .. DB.IDS[kind] .. "%d+$") ~= nil
end
DB.NAME_BYTES = 120
-- A macro's own commands: the game's 255 letters (MACROFRAME_CHAR_LIMIT), each up to 4 bytes; a note's text, 1000.
DB.MACRO_BYTES = 1020
DB.NOTE_BYTES = 4000
-- A macro's button's description: one line of 40 letters (UI/Hub/Macros.lua's DESC_LETTERS), each up to 4 bytes.
DB.DESC_BYTES = 160
-- A folder's role (UI/Hub/Seeds.lua's: "weapons", "stats"...), at most this long.
DB.ROLE_BYTES = 40
-- The status bars dragged in Edit Mode, by side: { x, y, w }, their bottom left and the width they had.
DB.PLACES = { left = true, right = true }
-- The status bars' settings that were shared ("statusText" and so on) until each bar had its own.
local SHARED_STATUS = { "Text", "Texture", "Ticks", "Numbers", "FontSize", "Width" }

local finite = ns.Finite

local function blank()
    return { version = DB.VERSION, options = {}, items = {}, folders = {}, macros = {}, separators = {}, copies = {},
        buttonsLeft = {}, statusPlaces = {}, gold = {}, plates = {}, seeds = {}, cvars = {}, chars = {}, presets = {} }
end
-- Tables a later build added: missing from an older file, they are made, not repaired.
local ADDED = { folders = true, macros = true, separators = true, buttonsLeft = true, statusPlaces = true, plates = true,
    seeds = true, cvars = true, chars = true, presets = true, copies = true }
-- What the settings are made of (Core/Sets.lua): the tables a character has of its own when it leaves the account's,
-- and a set kept under a name holds. Not the gold, the plates, the game's settings kept: each character's as it is.
DB.SET_FIELDS = { "options", "items", "folders", "macros", "separators", "copies", "buttonsLeft", "statusPlaces",
    "seeds" }
-- The game's own settings the HUD turns off while it has their part of the screen (`cvars`): each one's value as the
-- player had it, put back when the HUD gives that part back (UI/Minimap.lua: the coordinates under the map), and at
-- each logout, marked so (":back") to be taken again at the next login.
DB.KEPT_CVARS = { minimapShowPlayerCoords = true }

-- A character's frozen plate: the screen's size it was made at, when, and the frames, each a name and a rectangle.
-- One frame that isn't so goes, the rest stays.
local function repairPlate(p)
    if type(p) ~= "table" or not (finite(p.W) and finite(p.H) and type(p.frames) == "table") then
        return nil, 1
    end
    local fixed, frames = 0, {}
    for _, f in ipairs(p.frames) do
        if type(f) == "table" and type(f.key) == "string" and finite(f.x) and finite(f.y) and finite(f.w) and finite(f.h) then
            frames[#frames + 1] = f
        else
            fixed = fixed + 1
        end
    end
    if fixed > 0 then
        p.frames = frames
    end
    if p.t ~= nil and not finite(p.t) then
        p.t, fixed = nil, fixed + 1
    end
    -- what each status bar showed: { kind, shows }
    if p.bars ~= nil and type(p.bars) ~= "table" then
        p.bars, fixed = nil, fixed + 1
    end
    for side, b in pairs(p.bars or {}) do
        if not DB.PLACES[side] or type(b) ~= "table" or type(b.kind) ~= "string" or type(b.shows) ~= "boolean" then
            p.bars[side], fixed = nil, fixed + 1
        end
    end
    return p, fixed
end

local function badFolder(id, f)
    return not isId("folders", id) or type(f) ~= "table" or type(f.name) ~= "string" or f.name == ""
        or #f.name > DB.NAME_BYTES
end

-- A folder's settings put right; how many were wrong.
local function repairFolder(f)
    local fixed = 0
    for key, choices in pairs(DB.FOLDER_CHOICES) do
        if f[key] ~= nil and not choices[f[key]] then
            f[key] = nil
            fixed = fixed + 1
        end
    end
    local n = f.perLine
    if n ~= nil and not (finite(n) and n % 1 == 0 and n >= DB.PER_LINE[1] and n <= DB.PER_LINE[2]) then
        f.perLine = nil
        fixed = fixed + 1
    end
    -- overflow: where what doesn't fit on the bar goes (UI/Hub/InfoBar.lua's fit)
    -- align, dim: its list's values aligned on its right, those that say nothing in grey (UI/Hub/Folders.lua)
    for _, key in ipairs({ "opened", "default", "overflow", "iconOnly", "nameOnly", "align", "dim" }) do
        if f[key] ~= nil and f[key] ~= true then
            f[key] = nil
            fixed = fixed + 1
        end
    end
    fixed = fixed + DB.RepairLook(f)
    if f.role ~= nil and not (type(f.role) == "string" and f.role ~= "" and #f.role <= DB.ROLE_BYTES) then
        f.role = nil
        fixed = fixed + 1
    end
    return fixed
end

-- A macro (UI/Hub/Macros.lua): its name, its icon (the library's, else none), and what it runs, its own commands or
-- one of the game's macros by name, or nothing (a note, its text longer); one made by KaLi HUD, its seed (UI/Hub/
-- Seeds.lua's "<role>:<key>"). One with no name goes; a field that can't be goes, the rest stays.
local function badMacro(id, m)
    return not isId("macros", id) or type(m) ~= "table" or type(m.name) ~= "string" or m.name == ""
        or #m.name > DB.NAME_BYTES
end

-- A folder's or a macro's look (UI/Hub/Hub.lua's Hub.LookOf): its icon alone or its name alone, true, never both
-- (its name alone goes); how many were wrong.
function DB.RepairLook(t)
    local fixed = 0
    for _, key in ipairs({ "iconOnly", "nameOnly" }) do
        if t[key] ~= nil and t[key] ~= true then
            t[key], fixed = nil, fixed + 1
        end
    end
    if t.iconOnly and t.nameOnly then
        t.nameOnly, fixed = nil, fixed + 1
    end
    return fixed
end

local function repairMacro(m)
    local fixed = DB.RepairLook(m)
    if m.icon ~= nil and not DB.FOLDER_CHOICES.icon[m.icon] then
        m.icon, fixed = nil, fixed + 1
    end
    if m.note ~= nil and m.note ~= true then
        m.note, fixed = nil, fixed + 1
    end
    local most = m.note and DB.NOTE_BYTES or DB.MACRO_BYTES
    if m.text ~= nil and not (type(m.text) == "string" and #m.text <= most) then
        m.text, fixed = nil, fixed + 1
    end
    if m.macro ~= nil and not (type(m.macro) == "string" and m.macro ~= "" and #m.macro <= DB.NAME_BYTES) then
        m.macro, fixed = nil, fixed + 1
    end
    -- its right-click's own commands, as long as its own; its own tooltip, as long as a note's text (Ikar 2026-11-17)
    if m.right ~= nil and not (type(m.right) == "string" and m.right ~= "" and #m.right <= DB.MACRO_BYTES) then
        m.right, fixed = nil, fixed + 1
    end
    if m.tip ~= nil and not (type(m.tip) == "string" and m.tip ~= "" and #m.tip <= DB.NOTE_BYTES) then
        m.tip, fixed = nil, fixed + 1
    end
    -- its buttons' descriptions, a line each (Ikar 2026-11-18)
    for _, key in ipairs({ "leftDesc", "rightDesc" }) do
        local d = m[key]
        if d ~= nil and not (type(d) == "string" and d:find("%S") and not d:find("[\r\n]") and #d <= DB.DESC_BYTES) then
            m[key], fixed = nil, fixed + 1
        end
    end
    if m.seed ~= nil and not (type(m.seed) == "string" and m.seed:find("^[^:]+:.") and #m.seed <= DB.NAME_BYTES) then
        m.seed, fixed = nil, fixed + 1
    end
    return fixed
end

-- The saved table, made usable: { data, info } or nil and why it's refused. info.fixed counts values put right.
-- The file as it is kept: the account's settings where the settings in use are read. While a character plays on
-- its own, those stand there and the account's wait aside (`account`); this puts each back where it is kept, the
-- character's under its name. Before the game writes the file; and as it opens, for one written without this (the
-- game gone before its last event).
local function leave(db)
    local key, account = db.live, db.account
    if type(key) == "string" and type(account) == "table" then
        if type(db.chars) ~= "table" then
            db.chars = {}
        end
        local c = type(db.chars[key]) == "table" and db.chars[key] or {}
        db.chars[key] = c
        c.own, c.settings = true, {}
        for _, field in ipairs(DB.SET_FIELDS) do
            c.settings[field] = db[field]
            db[field] = account[field]
        end
        if type(c.settings.options) == "table" then
            setmetatable(c.settings.options, nil)
        end
        if type(db.options) == "table" then
            setmetatable(db.options, OPTIONS)
        end
    end
    db.live, db.account = nil, nil
end
DB.Leave = leave

function DB.Open(saved)
    if saved == nil then
        local data = blank()
        setmetatable(data.options, OPTIONS)
        return data, { firstRun = true, fixed = 0 }
    end
    if type(saved) ~= "table" then
        return nil, "not a table"
    end
    if not finite(saved.version) then
        return nil, "no version"
    end
    if saved.version > DB.VERSION then
        return nil, "version " .. tostring(saved.version)
    end
    leave(saved)
    local fixed = 0
    for key in pairs(blank()) do
        if key ~= "version" and type(saved[key]) ~= "table" then
            if saved[key] ~= nil or not ADDED[key] then
                fixed = fixed + 1
            end
            saved[key] = {}
        end
    end
    local o = saved.options
    for _, suffix in ipairs(SHARED_STATUS) do
        local shared = o["status" .. suffix]
        if shared ~= nil then
            for _, bar in ipairs({ "statusLeft", "statusRight" }) do
                if o[bar .. suffix] == nil then
                    o[bar .. suffix] = shared
                end
            end
            o["status" .. suffix] = nil
        end
    end
    -- the Ornates as drawn, with their blue, gone (Ikar 2026-11-16): a window folded by one keeps its piece, in silver
    o.foldArt = RETIRED_ARTS[o.foldArt] or o.foldArt
    o.minimapRing = RETIRED_RINGS[o.minimapRing] or o.minimapRing
    -- a cartouche's size, its ring's (50 to 200 % of one size for all) until 2026-11-20, its width as a share of its
    -- window's since (foldArtWidth): a size set before says nothing of that, so it goes, the default taken
    o.foldArtSize = nil
    -- the fold's animation a list until 2026-11-18 ("none", "blind", "shade"), now on or off: none off, either blind on
    if type(o.foldAnim) == "string" then
        o.foldAnim = o.foldAnim ~= "none"
    end
    -- the info bar's one size, its text's: the text size it had, its height and icons' gone
    if o.infoSize == nil and o.infoFontSize ~= nil then
        o.infoSize = o.infoFontSize
    end
    o.infoHeight, o.infoFontSize, o.infoIconSize = nil, nil, nil
    -- what was tried (Ikar 2026-11-16), now baked in or dropped: the border's profile, polish and notches, the light,
    -- the inner shadow and line, the action buttons' wells and empty slots; and the recesses' darkness (no recess);
    -- the clock's hours and whose time it tells, the game's own two settings read since 2026-11-17 (UI/Hub/Items.lua)
    for _, gone in ipairs({ "borderProfile", "borderPolish", "borderNotches", "light", "innerShade", "innerShadeAlpha",
        "innerLine", "slotWells", "emptySlotAlpha", "slotRecess", "clock24", "clockServer" }) do
        o[gone] = nil
    end
    for key, v in pairs(o) do
        local default = DB.DEFAULTS[key]
        local range = DB.RANGES[key]
        if default ~= nil and (type(v) ~= type(default)
            or DB.CHOICES[key] and not DB.CHOICES[key][v]
            or DB.COLORS[key] and not isColor(v)
            or range and not (finite(v) and v >= range[1] and v <= range[2])) then
            o[key] = nil
            fixed = fixed + 1
        end
    end
    for id, f in pairs(saved.folders) do
        if badFolder(id, f) then
            saved.folders[id] = nil
            fixed = fixed + 1
        else
            fixed = fixed + repairFolder(f)
        end
    end
    for id, m in pairs(saved.macros) do
        if badMacro(id, m) then
            saved.macros[id] = nil
            fixed = fixed + 1
        else
            fixed = fixed + repairMacro(m)
        end
    end
    -- a copy: the item it shows, by its name; one that isn't so goes
    for id, c in pairs(saved.copies) do
        if not isId("copies", id) or type(c) ~= "table" or type(c.of) ~= "string" or c.of == ""
            or #c.of > DB.NAME_BYTES then
            saved.copies[id] = nil
            fixed = fixed + 1
        end
    end
    for key, done in pairs(saved.seeds) do
        if done ~= true then
            saved.seeds[key] = nil
            fixed = fixed + 1
        end
    end
    for name, was in pairs(saved.cvars) do
        if not DB.KEPT_CVARS[name] or type(was) ~= "string" then
            saved.cvars[name] = nil
            fixed = fixed + 1
        end
    end
    -- an element's key is its name, a text: any other (a file edited by hand, or damaged) reached the code that reads
    -- names and stopped the first setup (the review of 2026-11-17)
    for name, item in pairs(saved.items) do
        if type(name) ~= "string" or type(item) ~= "table"
            or item.side ~= nil and not DB.SIDES[item.side]
            or item.last ~= nil and not DB.SIDES[item.last]
            or (item.side == "folder" or item.last == "folder") and not saved.folders[item.folder]
            or item.order ~= nil and not finite(item.order)
            or item.angle ~= nil and not (finite(item.angle) and item.angle >= 0 and item.angle < 360)
            or item.pos ~= nil and not (finite(item.pos) and item.pos >= 0 and item.pos <= 1)
            or item.show ~= nil and not DB.SHOW_MODES[item.show] then
            saved.items[name] = nil
            fixed = fixed + 1
        elseif item.slot ~= nil and not (finite(item.slot) and item.slot == math.floor(item.slot) and item.slot >= 1
            and item.slot <= 64) then
            -- a pocket's place that can't be: the first free one
            item.slot = nil
            fixed = fixed + 1
        end
        -- its look on the bar (UI/Hub/Hub.lua's SetItemLook): one that isn't goes, the element as it comes
        if saved.items[name] == item and type(item) == "table" and item.look ~= nil and not DB.ITEM_LOOKS[item.look] then
            item.look = nil
            fixed = fixed + 1
        end
    end
    -- a folder in a folder (UI/Hub/Folders.lua), never in itself: one in a ring of them goes back where it goes by
    -- default, the first by its id, the ring broken there
    local folderIds = {}
    for id in pairs(saved.folders) do
        folderIds[#folderIds + 1] = id
    end
    table.sort(folderIds)
    for _, id in ipairs(folderIds) do
        local at, steps = id, 0
        while steps <= #folderIds do
            local item = saved.items[at]
            if not (type(item) == "table" and item.side == "folder") then
                break
            end
            at, steps = item.folder, steps + 1
            if at == id then
                saved.items[id] = nil
                fixed = fixed + 1
                break
            end
        end
    end
    -- a separator stands in a folder (UI/Hub/Separators.lua): true, or its title and whether it starts a line of the
    -- list ({ name, line }); one that's anything else, or in no folder, goes; a field that can't be goes, the rest stays
    for id, on in pairs(saved.separators) do
        local item = saved.items[id]
        if not (on == true or type(on) == "table") or not isId("separators", id)
            or not (type(item) == "table" and item.side == "folder") then
            saved.separators[id] = nil
            fixed = fixed + 1
        elseif type(on) == "table" then
            for key, v in pairs(on) do
                local good = key == "name" and type(v) == "string" and v ~= "" and #v <= DB.NAME_BYTES
                    or key == "line" and v == true
                if not good then
                    on[key] = nil
                    fixed = fixed + 1
                end
            end
            if next(on) == nil then
                saved.separators[id] = true
            end
        end
    end
    for name, left in pairs(saved.buttonsLeft) do
        if type(name) ~= "string" or left ~= true then
            saved.buttonsLeft[name] = nil
            fixed = fixed + 1
        end
    end
    for side, place in pairs(saved.statusPlaces) do
        if not DB.PLACES[side] or type(place) ~= "table"
            or not (finite(place.x) and finite(place.y) and finite(place.w)) then
            saved.statusPlaces[side] = nil
            fixed = fixed + 1
        end
    end
    for key, entry in pairs(saved.gold) do
        if type(entry) ~= "table" or not finite(entry.money) then
            saved.gold[key] = nil
            fixed = fixed + 1
        end
    end
    for key, p in pairs(saved.plates) do
        local plate, wrong = repairPlate(p)
        saved.plates[key] = type(key) == "string" and plate or nil
        fixed = fixed + wrong + ((type(key) ~= "string" and plate) and 1 or 0)
    end
    -- each character's own settings and the sets kept under a name: one that isn't what it should be goes; what each
    -- holds is repaired when it is taken (DB.Repaired), as this file's is here
    for key, c in pairs(saved.chars) do
        if type(key) ~= "string" or type(c) ~= "table" or (c.settings ~= nil and type(c.settings) ~= "table") then
            saved.chars[key] = nil
            fixed = fixed + 1
        end
    end
    local sets = {}
    for _, p in pairs(saved.presets) do
        if type(p) == "table" and type(p.name) == "string" and p.name ~= "" and type(p.settings) == "table" then
            -- when it was kept and by whom, whether it is the settings as they were, whether it came from a text: one
            -- that can't be goes, the set stays (a date that was a text stopped its window from opening: the review
            -- of 2026-11-19)
            if p.at ~= nil and not finite(p.at) then
                p.at, fixed = nil, fixed + 1
            end
            if p.by ~= nil and type(p.by) ~= "string" then
                p.by, fixed = nil, fixed + 1
            end
            for _, mark in ipairs({ "backup", "imported" }) do
                if p[mark] ~= nil and p[mark] ~= true then
                    p[mark], fixed = nil, fixed + 1
                end
            end
            sets[#sets + 1] = p
        else
            fixed = fixed + 1
        end
    end
    table.sort(sets, function(a, b)
        return (tonumber(a.at) or 0) < (tonumber(b.at) or 0)
    end)
    saved.presets = sets
    saved.version = DB.VERSION
    setmetatable(o, OPTIONS)
    return saved, { firstRun = false, fixed = fixed }
end

-- Settings from elsewhere (a character's own, a set kept, a text imported) made fit to be used: the tables they are
-- made of, each repaired as the file's own are when it opens; nil for what can't be settings. A copy is what to hand
-- it: it is repaired in place.
function DB.Repaired(settings)
    if type(settings) ~= "table" then
        return nil
    end
    local file = { version = DB.VERSION }
    for _, field in ipairs(DB.SET_FIELDS) do
        file[field] = settings[field]
    end
    local opened = DB.Open(file)
    if not opened then
        return nil
    end
    local out = {}
    for _, field in ipairs(DB.SET_FIELDS) do
        out[field] = opened[field]
    end
    setmetatable(out.options, nil)
    return out
end

-- As a character logs in: its own settings in the settings' place where it has some, the account's set aside until
-- the file is written (leave). False when it plays on the account's.
function DB.Enter(db, key)
    local c = db.chars[key]
    if not (type(c) == "table" and c.own == true and type(c.settings) == "table") then
        return false
    end
    local own = DB.Repaired(c.settings)
    if not own then
        c.own, c.settings = false, nil
        return false
    end
    db.account = {}
    for _, field in ipairs(DB.SET_FIELDS) do
        db.account[field] = db[field]
        db[field] = own[field]
    end
    setmetatable(db.options, OPTIONS)
    c.settings = nil
    db.live = key
    return true
end

-- Before the game writes the file: options back at their default go, and no number it can't write back stays.
function DB.BeforeSave(db)
    local o = db.options
    for key, v in pairs(o) do
        if DB.DEFAULTS[key] == v then
            o[key] = nil
        end
    end
    ns.DropNonFinite(db)
    leave(db)
end
