-- Sets of settings (Ikar 2026-11-19: "we should have to duplicate from another alt too. Maybe save/update/create
-- custom preset", then, the ways of other addons looked into, "ok, but this should go into the setting windows").
--
-- The settings are the account's, live, the same for every character: what players ask for first, and the game's own
-- way (its key bindings, its macros). A character may have its own instead, as the game's « Raccourcis clavier
-- propres au personnage »: it starts from a copy of the account's and no longer follows them; back on the account's,
-- its own are kept as a set.
--
-- A set, « Préréglage » to the player (the nine looks of Data/Presets.lua are « Style »), is a copy of all the
-- settings kept under a name: saved from the settings as they are, applied, brought up to date, renamed, deleted.
-- Applying copies it into the settings, part by part (his: "a checkbox for each state, on by default"), and keeps
-- the settings as they were as a set of its own, which is the way back. Another character's own settings are applied
-- the same way.
--
-- What the settings are made of is Core/DB.lua's (SET_FIELDS); the saved file holds, beside the settings in use, the
-- account's while a character's own are in (`account`, `live`), each character's own (`chars`) and the sets
-- (`presets`).
local _, ns = ...

local Sets = {}
ns.Sets = Sets

local DB = ns.DB
local L = ns.L

-- The sets a player keeps at most, and the settings as they were kept at most: the page has no more room.
Sets.MOST, Sets.BACKUPS = 10, 3

-- The parts a set is applied by, in the order the player reads them: the look (a style's own values, with the
-- borders', the backgrounds' and the cartouche's sizes); the plate, the margins and the minimap; the status bars and
-- where they were dragged; the info bar with all it holds (its elements' places, the folders, the macros and the
-- notes, a folder's macros going with it); what the HUD does by itself and what it sounds like.
Sets.PARTS = { "look", "plate", "status", "bar", "behaviour" }
local LOOK = { preset = true, borderSize = true, borderAlpha = true, bgIntensity = true, bgAlpha = true,
    foldArtWidth = true, foldArtLift = true }
for _, key in ipairs(ns.PRESET_KEYS) do
    LOOK[key] = true
end
local BEHAVIOUR = { minimapAutoZoom = true, chatPeekOnType = true, meterUnfoldCombat = true, folderCombatClose = true,
    hideExternalXP = true, manaPerSecond = true, foldAnim = true, foldSound = true, folderSound = true }
-- What is no setting but how things stand: the chat and the meter folded or not, the padlock shut or open. Neither
-- kept in a set nor taken from one: a set from another player folded the chat and opened the padlock of whoever
-- applied it (the review of 2026-11-19).
local STATE = { chatFolded = true, meterFolded = true, slotsLocked = true }
-- The tables the bar's undo doesn't follow (UI/Hub/History.lua's own are the six others), which a set that fails
-- half way puts back itself.
local UNFOLLOWED = { "buttonsLeft", "statusPlaces", "seeds" }
local BAR = { infoBar = true, infoSize = true, infoSpacing = true, copper = true, bagsFree = true }
local TABLES = {
    status = { "statusPlaces" },
    bar = { "items", "folders", "macros", "separators", "copies", "buttonsLeft", "seeds" },
}
-- What is no setting: whether a folder's list is open.
local VOLATILE = { folders = { opened = true } }

-- The part an option belongs to: one this build has no default of is an element's own, the info bar's.
function Sets.PartOf(key)
    if LOOK[key] then
        return "look"
    elseif BEHAVIOUR[key] then
        return "behaviour"
    elseif BAR[key] or DB.DEFAULTS[key] == nil then
        return "bar"
    elseif tostring(key):find("^status") then
        return "status"
    end
    return "plate"
end

local function copy(v, skip)
    if type(v) ~= "table" then
        return v
    end
    local t = {}
    for k, x in pairs(v) do
        if not (skip and skip[k]) then
            t[k] = copy(x)
        end
    end
    return t
end

-- The settings as they are, copied whole.
function Sets.Capture()
    local set = {}
    for _, field in ipairs(DB.SET_FIELDS) do
        local rows, skip = {}, VOLATILE[field]
        for key, v in pairs(ns.db[field]) do
            if not (field == "options" and STATE[key]) then
                rows[key] = copy(v, skip)
            end
        end
        set[field] = rows
    end
    return set
end

-- ---------- The sets kept ----------

-- All of them, in the order made: { name, at, by, backup, settings }; a backup is the settings as they were before a
-- set was applied.
function Sets.List()
    return ns.db.presets
end

local function count(backup)
    local n = 0
    for _, p in ipairs(ns.db.presets) do
        n = n + ((p.backup == true) == backup and 1 or 0)
    end
    return n
end

-- The settings as they are kept under `name` (or `settings`, from a text, the set marked `imported`: its window says
-- what a set from someone else may hold); the set, or nil with no name or no room left for one more.
function Sets.Save(name, settings, imported)
    if type(name) ~= "string" or name:match("^%s*$") or count(false) >= Sets.MOST then
        return nil
    end
    local set = { name = name, at = time(), by = ns.CharKey(), settings = settings or Sets.Capture(),
        imported = imported and true or nil }
    table.insert(ns.db.presets, set)
    return set
end

-- `settings` kept as a set whatever the room left: what is kept without the player asking (a character's own
-- settings as it goes back to the account's) is never dropped for want of room, nor goes as the settings as they
-- were do, the oldest past the few kept. Deleting it is the player's.
local function keep(name, settings)
    local set = { name = name, at = time(), by = ns.CharKey(), settings = settings }
    table.insert(ns.db.presets, set)
    return set
end

-- `settings` kept as what the settings were, named `name`; the oldest such goes past the few kept.
function Sets.Backup(settings, name)
    local list = ns.db.presets
    list[#list + 1] = { name = name, at = time(), by = ns.CharKey(), backup = true, settings = settings }
    while count(true) > Sets.BACKUPS do
        for i, p in ipairs(list) do
            if p.backup then
                table.remove(list, i)
                break
            end
        end
    end
end

local function indexOf(set)
    for i, p in ipairs(ns.db.presets) do
        if p == set then
            return i
        end
    end
end

-- A set brought up to date: the settings as they are in place of what it held.
function Sets.Update(set)
    if not indexOf(set) then
        return false
    end
    set.settings, set.at, set.by, set.imported = Sets.Capture(), time(), ns.CharKey(), nil
    return true
end

function Sets.Rename(set, name)
    if not indexOf(set) or type(name) ~= "string" or name:match("^%s*$") then
        return false
    end
    set.name = name
    return true
end

function Sets.Delete(set)
    local i = indexOf(set)
    if not i then
        return false
    end
    table.remove(ns.db.presets, i)
    return true
end

-- ---------- As a text ----------
-- (Ikar 2026-11-19: "let's do a proper export and import".) A set written as a text to copy and hand to another
-- player, or to oneself on another account: its settings and the version that wrote them, by the game's own means
-- (C_EncodingUtil: CBOR, deflated, in base 64), after a head that says what the text is and its format's number. Read
-- back: what isn't such a text is told from one that is cut and from one a newer version wrote; its settings are
-- repaired as the file's own are when it opens, so nothing of a text reaches the HUD unchecked.
Sets.FORMAT = 1
local HEAD = "KaLiHUD:"

function Sets.Export(settings)
    local E = C_EncodingUtil
    if not (E and E.SerializeCBOR and E.CompressString and E.EncodeBase64) then
        return nil
    end
    local ok, text = pcall(function()
        return E.EncodeBase64(E.CompressString(E.SerializeCBOR({ addon = ns.VERSION, settings = settings })))
    end)
    return ok and type(text) == "string" and (HEAD .. Sets.FORMAT .. ":" .. text) or nil
end

-- A text's settings, and the version that wrote it; or nil and why: "not" a set's text, "cut", or from a "newer"
-- version.
function Sets.Read(text)
    if type(text) ~= "string" then
        return nil, "not"
    end
    text = text:gsub("%s+", "")
    local format, body = text:match("^" .. HEAD .. "(%d+):(.+)$")
    if not format then
        return nil, "not"
    end
    if tonumber(format) > Sets.FORMAT then
        return nil, "newer"
    end
    local E = C_EncodingUtil
    local ok, data = pcall(function()
        return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(body)))
    end)
    if not ok or type(data) ~= "table" or type(data.settings) ~= "table" then
        return nil, "cut"
    end
    local settings = DB.Repaired(data.settings)
    if not settings then
        return nil, "cut"
    end
    return settings, data.addon
end

-- ---------- Applying ----------

-- `settings` copied into the settings in use, the parts named alone (all of them with none named), what the others
-- hold left as it is; the settings as they were kept as a set named `kept`. Each row is put in place of the one it
-- replaces, in the tables the HUD's pieces read, which are told as an undo tells them (UI/Hub/History.lua), and the
-- whole HUD is drawn again. Not in a fight, the bar's buttons being the game's protected ones. True once done; false
-- when refused, when `settings` aren't settings, or when it failed (all put back: the five tables the bar's undo
-- follows by it, the three others here).
function Sets.Apply(settings, parts, kept)
    local set = DB.Repaired(copy(settings))
    if not set then
        return false
    end
    local take = {}
    for _, part in ipairs(parts or Sets.PARTS) do
        take[part] = true
    end
    local before = Sets.Capture()
    local done = ns.History.Replace(function()
        local o, keys = ns.db.options, {}
        for key in pairs(o) do
            keys[key] = true
        end
        for key in pairs(set.options) do
            keys[key] = true
        end
        for key in pairs(keys) do
            if take[Sets.PartOf(key)] and not STATE[key] then
                o[key] = set.options[key]
            end
        end
        for part, fields in pairs(TABLES) do
            if take[part] then
                for _, field in ipairs(fields) do
                    local live = ns.db[field]
                    wipe(live)
                    for key, v in pairs(set[field]) do
                        live[key] = copy(v)
                    end
                end
            end
        end
    end)
    if not done then
        for _, field in ipairs(UNFOLLOWED) do
            local live = ns.db[field]
            wipe(live)
            for key, v in pairs(before[field]) do
                live[key] = copy(v)
            end
        end
        return false
    end
    if kept then
        Sets.Backup(before, kept)
    end
    -- a set kept by an earlier build: its locked folders as this one makes them (UI/Hub/Seeds.lua)
    if take.bar then
        ns.History.Attempt(ns.Seeds.Sync)
    end
    ns.ApplyAll()
    return true
end

-- ---------- The account's settings, or the character's own ----------

function Sets.Own()
    return ns.db.live ~= nil
end

-- This character on its own settings, or back on the account's. Its own start as a copy of the account's as they
-- are: the settings in use become its own where they stand, and the copy is the account's from then on, so nothing is
-- drawn again. Back on the account's, those are applied whole, and its own are kept as a set of the player's (keep),
-- not as the settings as they were: of those the oldest goes, and a character's own, three sets applied later, went
-- with it for good (the review of 2026-11-19). The page asks before this (UI/Options.lua). True once it is so.
function Sets.SetOwn(own)
    local db, key = ns.db, ns.CharKey()
    if own == Sets.Own() then
        return true
    end
    local c = type(db.chars[key]) == "table" and db.chars[key] or {}
    local name = string.format(L.SET_OWN_KEPT, UnitName("player") or "?")
    if own then
        -- settings left under its name that nothing reads (a file from elsewhere): kept as a set, not dropped
        if type(c.settings) == "table" then
            keep(name, c.settings)
        end
        db.account = Sets.Capture()
        -- (how things stand is the account's too)
        for state in pairs(STATE) do
            db.account.options[state] = rawget(db.options, state)
        end
        db.chars[key] = c
        c.own, c.settings = true, nil
        db.live = key
        return true
    end
    local mine = Sets.Capture()
    if not Sets.Apply(db.account) then
        return false
    end
    keep(name, mine)
    db.account, db.live = nil, nil
    c.own = false
    return true
end

-- The other characters who have settings of their own: { key, name, settings }, by name.
function Sets.Others()
    local list, mine = {}, ns.CharKey()
    for key, c in pairs(ns.db.chars) do
        if key ~= mine and type(c) == "table" and c.own == true and type(c.settings) == "table" then
            list[#list + 1] = { key = key, name = key:match("%-(.+)$") or key, settings = c.settings }
        end
    end
    table.sort(list, function(a, b)
        return a.key < b.key
    end)
    return list
end
