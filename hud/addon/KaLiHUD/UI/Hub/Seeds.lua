-- The folders KaLi HUD makes for the player: those its items stand in by default, each with its role
-- (Folders.ByRole), and the macros worth having there.
-- - « Emote » (Ikar 2026-11-16: "a folder, with emote (bulle icon) and vocal emote (lien de discussion)"; then "I
--   asked for a list of all the emotes, not just 2, they just need to be split into 2 categories, with different
--   icons"): every emote of the chat menu, the speech bubble on them, then every voice emote, the chat link on them,
--   each named and run by its slash command in the player's language, as the chat menu has them.
-- - The folders of what the bar shows (Ikar 2026-11-16, his list): weapon skills, professions, attributes, reagents,
--   statistics, guild, group and raid, session, and the others in « Infos »; each icon alone on its button, its list
--   of icons with their text running down, a separator a rule between its groups. Added at the inner end of the bar's
--   left side, where there's room (the map stands near the screen's right edge, its side of the bar short), so nothing
--   already on the bar moves.
-- These are locked folders (Ikar 2026-11-23: "Maybe we could avoid that nightmare by making them read only ? No edit,
-- no reset, user can delete them whole (and bring back) and if they drag and drop, it create a copy"; "let's call them
-- "locked" folder. In the future, extensions may create their own. The type shoudl be also "locked folder""). What
-- each holds is the code's, made again at each login (Seeds.Sync): a later build's contents reach a game saved before
-- with no step of their own, where each change had needed one (eleven of them by then, each a migration with its
-- tests). None is renamed, given another icon or settings, filled or emptied, nor reset; taken off the HUD whole from
-- its menu, it comes back from the bar's menu; what is dragged out of one lands as a copy (Seeds.Copy), the folder
-- keeping its own. How it opens alone is the player's (Ikar 2026-11-25: "users shoudl be able to set opening
-- behaviour, even on locked folders"): its spec's way till another is chosen (UI/Hub/Folders.lua's defaultOf), kept
-- through each login's making it again. A spec saying `locked` makes one; « Add-ons » and « Suite », made here too, are
-- none: they hold what lands in them, other addons' buttons among it, which can't be copied.
local _, ns = ...

local Seeds = {}
ns.Seeds = Seeds

local Hub, L = ns.Hub, ns.L

-- In a folder's contents: a separator.
Seeds.SEP = "|"
-- A separator with a title, starting a line of the list or not (UI/Hub/Separators.lua): `name` gives its title, in
-- the game's words where it has them, taken as the folder is made, as a folder's name is.
function Seeds.Title(name, line)
    return { sep = true, name = name, line = line or nil }
end
-- Whether an entry of the contents is a separator, plain or with a title; the fields it's made with.
local function isSep(entry)
    return entry == Seeds.SEP or type(entry) == "table" and entry.sep == true
end
Seeds.IsSep = isSep
local function sepSpec(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local name = entry.name
    if type(name) == "function" then
        name = name()
    end
    return { name = name, line = entry.line }
end
-- What each folder made here holds, in its order, filled by the files that make the items (UI/Hub/Infos/*.lua): an
-- item's name, Seeds.SEP or a Seeds.Title, or a macro's fields { name, icon, text, seed }, its seed its key among its
-- folder's macros.
Seeds.Contents = {}

-- How many to a column, separators not counted (Ikar 2026-11-16: "let's add column even for text"; "max number should
-- handle them"): 9 the group's eight world markers with their clearing; 11 each kind of emote (22 each) in two. The
-- attributes' their own (STATS_PER_LINE, below), their columns started by their titles.
local PER_LINE, EMOTES_PER_LINE, REPUTATIONS_PER_LINE = 9, 11, 12

local SPEAK, CHAT = "common-icon-speak", "common-icon-chatlink"
-- The voice emote of the player's faction: the macros are the account's, its characters of both factions.
local FACTION_TOKENS = { FORTHEALLIANCE = true, FORTHEHORDE = true }

-- The folders, each added at the inner end of the bar's left side, in this order: role, name, icon (the library's);
-- each its icon alone on its button, its list of icons with their text running down, opening up and right from the
-- bar's left.
local FOLDERS = {
    { role = "weapons", name = function() return L.FOLDER_WEAPONS end, icon = "combat_swords-icon" },
    { role = "professions", name = function() return ns.G("TRADE_SKILLS", "Professions") end,
        icon = "UI-HUD-MicroMenu-Professions-Up" },
    { role = "stats", name = function() return ns.G("STAT_CATEGORY_ATTRIBUTES", "Attributes") end,
        icon = "Mobile-MechanicIcon-Powerful" },
    { role = "reagents", name = function() return L.FOLDER_REAGENTS end, icon = "bags-icon-reagents" },
    { role = "statistics", name = function() return ns.G("STATISTICS", "Statistics") end,
        icon = "UI-HUD-MicroMenu-Achievements-Up" },
    { role = "guild", name = function() return ns.G("GUILD", "Guild") end, icon = "UI-HUD-MicroMenu-GuildCommunities-Up" },
    { role = "group", name = function() return L.FOLDER_GROUP end, icon = "friends-icon-tab-raid" },
    { role = "session", name = function() return L.FOLDER_SESSION end, icon = "UI-HUD-MicroMenu-GameMenu-Up" },
    { role = "infos", name = function() return L.FOLDER_INFOS end, icon = "glueannouncementpopup-icon-info" },
    -- the reputations (Ikar 2026-11-17: "We can add a reputation folder"; UI/Hub/Infos/Reputation.lua)
    { role = "reputations", name = function() return ns.G("REPUTATION", "Reputation") end, icon = "delves-scenario-flag" },
}
-- Those whose items are a name and a value: the values aligned on the list's right; those that say nothing in grey
-- but a reagent's 0, red for a warning (Ikar 2026-11-20: "fais un tour sur tous nos menus et vois comment les
-- améliorer avec ce système"). The attributes' a column for each of the sheet's three parts, under its titles: what
-- the character is, how it attacks, how it stands (UI/Hub/Infos/Stats.lua), fourteen in the second.
local VALUES = { stats = "dim", statistics = "dim", reputations = "align", weapons = "align", professions = "align",
    reagents = "align" }
Seeds.STATS_PER_LINE = 16
for i, spec in ipairs(FOLDERS) do
    spec.index, spec.style, spec.flow, spec.iconOnly, spec.perLine, spec.dir = i, "text", "vertical", true, PER_LINE,
        "upright"
    spec.locked = true
    spec.align, spec.dim = VALUES[spec.role] and true or nil, VALUES[spec.role] == "dim" or nil
    if spec.role == "stats" then
        -- open beside what is tried on its lines, a click elsewhere leaving it (Ikar 2026-11-25: "make it default for
        -- stats")
        spec.perLine, spec.open = Seeds.STATS_PER_LINE, "persist"
    end
end
-- a character knows some forty factions: the most to a column
FOLDERS[#FOLDERS].perLine = REPUTATIONS_PER_LINE
-- « Emote », second from the bar's right end; « Add-ons », where other addons' buttons land (UI/Hub/Folders.lua's
-- Setup), at that end, holding what lands in it (`keeps`), nothing of its own.
-- « Suite », where what doesn't fit on the bar goes (UI/Hub/InfoBar.lua's fit), at the bar's right end by the padlock:
-- its chevron alone on its button, its list of icons with their text running down, opening up and left; it holds what
-- the layout puts in it and what the player does (`keeps`), nothing of its own. Made, it is the folder that takes
-- what doesn't fit (`overflow`: the box of its menu ticked).
local SPECS = {
    emotes = { role = "emotes", name = function() return ns.G("EMOTE", "Emote") end, icon = SPEAK, style = "text",
        flow = "vertical", perLine = EMOTES_PER_LINE, side = "right", at = 2, locked = true },
    addons = { role = "addons", name = function() return L.FOLDER_ADDONS end, side = "right", at = 1, keeps = true },
    overflow = { role = "overflow", name = function() return L.FOLDER_OVERFLOW end, icon = "uitools-icon-chevron-right",
        style = "text", flow = "vertical", perLine = PER_LINE, dir = "upleft", iconOnly = true, side = "right", at = 1,
        keeps = true, overflow = true },
}
for _, spec in ipairs(FOLDERS) do
    SPECS[spec.role] = spec
end
-- The locked ones, in the order a first install makes them: « Emote », then the bar's left side's.
local LOCKED = { SPECS.emotes }
for _, spec in ipairs(FOLDERS) do
    LOCKED[#LOCKED + 1] = spec
end

-- Each emote's slash command by its token, as the chat menu names them (Blizzard_ChatFrameBase's EMOTEn_TOKEN and
-- EMOTEn_CMD1, n up to MAXEMOTEINDEX, not all of them there).
local function emoteCommands()
    local commands = {}
    local last = type(MAXEMOTEINDEX) == "number" and MAXEMOTEINDEX or 700
    for i = 1, last do
        local token, command = _G["EMOTE" .. i .. "_TOKEN"], _G["EMOTE" .. i .. "_CMD1"]
        if type(token) == "string" and type(command) == "string" and command ~= "" then
            commands[token] = commands[token] or command
        end
    end
    return commands
end

-- The chat menu's list `tokens` as macros wearing `icon`, put in `into`, each's seed its kind and token.
local function emotes(tokens, commands, icon, kind, into)
    for _, token in ipairs(type(tokens) == "table" and tokens or {}) do
        local command = commands[token]
        if command and not FACTION_TOKENS[token] then
            into[#into + 1] = { name = command, icon = icon, text = command, seed = "emotes:" .. kind .. "-" .. token }
        end
    end
end

-- What folder `role` holds as made, in order: an item's name, Seeds.SEP, or a macro's fields { name, icon, text,
-- seed }, its seed "<role>:<key>". A new list.
function Seeds.ContentsOf(role)
    local list = {}
    if role == "emotes" then
        -- each kind under its title, the game's words; the voices from a column of their own (Ikar 2026-11-20:
        -- "fais un tour sur tous nos menus et vois comment les améliorer avec ce système")
        local commands = emoteCommands()
        list[#list + 1] = { sep = true, name = ns.G("EMOTE", "Emote") }
        emotes(_G.EmoteList, commands, SPEAK, "emote", list)
        list[#list + 1] = { sep = true, name = ns.G("VOICEMACRO_LABEL", "Voice Emote"), line = true }
        emotes(_G.TextEmoteSpeechList, commands, CHAT, "voice", list)
        return list
    end
    for _, entry in ipairs(Seeds.Contents[role] or {}) do
        if type(entry) == "table" and entry.sep then
            local name = entry.name
            if type(name) == "function" then
                name = name()
            end
            list[#list + 1] = { sep = true, name = type(name) == "string" and name ~= "" and name or nil,
                line = entry.line }
        elseif type(entry) == "table" then
            list[#list + 1] = { name = entry.name, icon = entry.icon, text = entry.text, right = entry.right,
                leftDesc = entry.leftDesc, rightDesc = entry.rightDesc,
                seed = role .. ":" .. tostring(entry.seed or entry.text) }
        else
            list[#list + 1] = entry
        end
    end
    return list
end

-- The settings a spec gives a folder; how it opens not among them, the player's (its spec's way the folder's
-- default: UI/Hub/Folders.lua's defaultOf).
local SETTINGS = { "icon", "style", "flow", "perLine", "dir", "iconOnly", "nameOnly", "align", "dim" }

-- Folder f as `spec` makes it: its name, icon and settings, what the spec doesn't say the folders' default.
local function settle(f, spec)
    for _, key in ipairs(SETTINGS) do
        f[key] = nil
    end
    f.name = spec.name()
    f.icon, f.style, f.flow, f.perLine, f.dir, f.iconOnly = spec.icon, spec.style, spec.flow, spec.perLine, spec.dir,
        spec.iconOnly
    f.align, f.dim = spec.align, spec.dim
end

-- Where folder id made as `spec` stands: at its place on the bar's right, or at the inner end of its left side,
-- before those made after it there.
local function place(id, spec)
    if spec.side then
        Hub.Insert(id, spec.side, spec.at)
        return
    end
    local at
    for i, e in ipairs(Hub.Side("left", id)) do
        local f = e.isFolder and ns.Folders.Get(e.name)
        local other = f and f.role and SPECS[f.role]
        if other and other.index and other.index > spec.index then
            at = i
            break
        end
    end
    Hub.Insert(id, "left", at)
end

local function makeFolder(spec)
    local id = ns.Folders.Create(spec.name(), false, spec.role)
    settle(ns.Folders.Get(id), spec)
    place(id, spec)
    return id
end

-- At login (Hub.Start), after « Add-ons » (UI/Hub/Folders.lua's Setup): the locked folders as the code has them
-- (Seeds.Sync), at each login, with no mark, which would keep a later build's out. A reload in a fight waits for its
-- end.
function Seeds.Run()
    if InCombatLockdown() then
        local function later()
            ns.Off("PLAYER_REGEN_ENABLED", later)
            ns.SafeCall(Seeds.Run)
        end
        ns.On("PLAYER_REGEN_ENABLED", later)
        return
    end
    Seeds.Sync()
end

-- The folder for what doesn't fit on the bar (Ikar 2026-11-17: "Maybe a special folder ?"), made the first time
-- something doesn't, by the layout that finds it so (never in a fight, when nothing is laid out); once
-- (`db.seeds.overflow`): deleted, it isn't made again, and what doesn't fit waits for room. At the bar's right end, by
-- the padlock, before every other item there, so none of them moves in the saved order. Its id, nil when not made.
-- Made whole or not at all (History.Attempt); one that failed isn't tried again before the next login: the layout
-- asks at each of its passes.
local function makeOverflow()
    local spec = SPECS.overflow
    local id = ns.Folders.Create(spec.name(), false, spec.role)
    local f = ns.Folders.Get(id)
    settle(f, spec)
    f.overflow = spec.overflow
    Hub.PlaceAt(id, "right", 0)
    Hub.Changed()
    return id
end

local overflowFailed = false
function Seeds.Overflow()
    local seeds = ns.db.seeds
    if seeds.overflow or overflowFailed or InCombatLockdown() then
        return nil
    end
    local ok, id = ns.History.Attempt(makeOverflow)
    if not ok then
        overflowFailed = true
        return nil
    end
    seeds.overflow = true
    return id
end

-- ---------- The locked folders ----------

-- A folder's spec, its role's; nil for one of the player's.
function Seeds.FolderSpec(id)
    local f = ns.Folders.Get(id)
    return f and f.role and SPECS[f.role] or nil
end

-- Whether folder `id` is a locked one: made for a role whose spec says so.
function Seeds.IsLockedFolder(id)
    local spec = Seeds.FolderSpec(id)
    return spec ~= nil and spec.locked == true
end

-- Whether `name` stands in a locked folder (by its own place, or by its home): it moves nowhere, nothing of it
-- changes, and a drag takes a copy of it out.
function Seeds.InLockedFolder(name)
    local e = Hub.Entry(name)
    return e ~= nil and e.side == "folder" and Seeds.IsLockedFolder(e.folder)
end

-- Whether one of ours is made for a locked folder (its obj.home): never listed on its own in the bar's menu, its
-- folder's box standing for it there.
function Seeds.HomeLocked(obj)
    local spec = type(obj) == "table" and obj.home and SPECS[obj.home]
    return spec ~= nil and spec.locked == true
end

-- Whether `name` is one of what KaLi HUD brings: ours, a folder made here, a macro made for a locked folder.
function Seeds.IsBundled(name)
    local m = ns.Macros.Get(name)
    return Hub.IsOurs(name) or Seeds.FolderSpec(name) ~= nil or (m ~= nil and m.seed ~= nil)
end

-- A macro's fields as saved against those it's made with.
local MACRO_FIELDS = { "name", "icon", "text", "macro", "note", "right", "tip", "leftDesc", "rightDesc", "iconOnly",
    "nameOnly", "seed" }
local function differs(m, spec)
    for _, key in ipairs(MACRO_FIELDS) do
        if m[key] ~= spec[key] then
            return true
        end
    end
    return false
end

-- Folder id, locked, as the code makes it for `role`: its name, icon and settings; its contents in their order, each
-- macro made for it as made (one missing made anew), its separators titled as made; then those of ours made for it
-- that its list doesn't name, by their home. What the code no longer puts in it goes: its separators and KaLi HUD's
-- macros deleted, anything else where it goes with no place saved.
local function sync(id, role)
    settle(ns.Folders.Get(id), SPECS[role])
    local members, bySeed, seps = Hub.InFolder(id), {}, {}
    for _, e in ipairs(members) do
        local m = e.isMacro and ns.Macros.Get(e.name)
        if m and m.seed then
            bySeed[m.seed] = bySeed[m.seed] or e.name
        elseif e.isSeparator then
            seps[#seps + 1] = e.name
        end
    end
    local order, keep, s = {}, {}, 0
    local function add(name)
        if name and not keep[name] then
            keep[name] = true
            order[#order + 1] = name
        end
    end
    for _, entry in ipairs(Seeds.ContentsOf(role)) do
        if isSep(entry) then
            s = s + 1
            local name = seps[s]
            if name then
                ns.Separators.Dress(name, sepSpec(entry))
            else
                name = ns.Separators.Make(sepSpec(entry))
            end
            add(name)
        elseif type(entry) == "table" then
            local name = bySeed[entry.seed]
            if not name then
                name = ns.Macros.Create(entry)
            elseif differs(ns.Macros.Get(name), entry) then
                ns.Macros.Restore(name, entry)
            end
            add(name)
        else
            add(entry)
        end
    end
    -- by their home: after the list where it has one, else in their own order, no place saved (a skill learnt later
    -- takes its place among them)
    local listed = #order > 0
    for _, e in ipairs(Hub.Entries()) do
        if e.ours and not e.isCopy and type(e.obj) == "table" and e.obj.home == role and not keep[e.name] then
            if listed then
                add(e.name)
            else
                keep[e.name] = true
                Hub.Unplace(e.name)
            end
        end
    end
    for _, e in ipairs(members) do
        if not keep[e.name] then
            if e.isSeparator then
                ns.Separators.Drop(e.name)
            elseif e.isMacro and ns.Macros.Get(e.name).seed then
                ns.Macros.Delete(e.name)
            else
                Hub.Unplace(e.name)
            end
        end
    end
    for i, name in ipairs(order) do
        Hub.PlaceAt(name, "folder", i * 10, id)
    end
    ns.Folders.Refresh(id)
end

-- One locked folder as the code makes it: made at its place if it isn't there (a first install's, or one a later
-- build adds), then, shown or taken off the HUD, holding what the code says.
local function lockOne(spec)
    sync(ns.Folders.ByRole(spec.role) or makeFolder(spec), spec.role)
end

-- Every locked folder as the code makes it, each whole or not at all on its own (History.Attempt): one that raises an
-- error leaves nothing of itself and is tried again at the next login, those after it made all the same (all made in
-- one go, one failing had left none that session: the review of 2026-11-18, R5). « Add-ons » and « Suite » named in
-- the game's language too (renamed, a folder has no role: the player's name stays). At each login (Seeds.Run), and
-- after a set is applied (Core/Sets.lua). Not during a fight, when the bar holds still.
function Seeds.Sync()
    if InCombatLockdown() then
        return false
    end
    for _, spec in ipairs(LOCKED) do
        ns.History.Attempt(lockOne, spec)
    end
    for _, id in ipairs(ns.Folders.List()) do
        local spec = Seeds.FolderSpec(id)
        if spec and not spec.locked then
            ns.Folders.Get(id).name = spec.name()
            ns.Folders.Refresh(id)
        end
    end
    Hub.Changed()
    return true
end

-- What a drag out of a locked folder puts down: a copy of `name`, its id, the folder keeping its own (an item's copy
-- shows the item, UI/Hub/Hub.lua's; a macro's and a separator's are the player's own); nil for what stands in none.
-- Not drawn.
function Seeds.Copy(name)
    if not Seeds.InLockedFolder(name) then
        return nil
    end
    local m = ns.Macros.Get(name)
    if m then
        return ns.Macros.Create({ name = m.name, icon = m.icon, text = m.text, macro = m.macro, note = m.note,
            right = m.right, tip = m.tip, leftDesc = m.leftDesc, rightDesc = m.rightDesc })
    elseif ns.Separators.IsId(name) then
        return ns.Separators.Make({ name = ns.Separators.Name(name), line = ns.Separators.StartsLine(name) })
    end
    return Hub.NewCopy(name)
end

-- One of ours back as it comes: its own options (its obj.options) at their defaults, where it goes by default. Not
-- one in a locked folder, which has nothing to reset; false during a fight.
function Seeds.ResetItem(name)
    local obj = Hub.IsOurs(name) and Hub.Object(name)
    if type(obj) ~= "table" or InCombatLockdown() or Seeds.InLockedFolder(name) then
        return false
    end
    for _, key in ipairs(type(obj.options) == "table" and obj.options or {}) do
        ns.db.options[key] = nil
    end
    Hub.Unplace(name)
    Hub.Changed()
    return true
end

-- « Add-ons » or « Suite » deleted (Ikar 2026-11-20: "and I still don't see how to bring back my emote folder"): its
-- role, for the bar's menu to list under « Dossiers », unticked. A locked folder is never deleted, only taken off the
-- HUD: its box there is ticked or not.
function Seeds.Missing()
    local list = {}
    for _, role in ipairs({ "addons", "overflow" }) do
        -- (« Suite » only once made: it waits for the first time something doesn't fit, Seeds.Overflow)
        if not ns.Folders.ByRole(role) and (role ~= "overflow" or ns.db.seeds.overflow) then
            list[#list + 1] = { role = role, name = SPECS[role].name() }
        end
    end
    return list
end

-- One of them made again as made: its place, its settings; « Add-ons » where new addons land again while no other
-- folder was told to take them, « Suite » the folder that takes what doesn't fit. Its id, nil during a fight or while
-- it's there.
function Seeds.Restore(role)
    local spec = SPECS[role]
    if not spec or spec.locked or ns.Folders.ByRole(role) or InCombatLockdown() then
        return nil
    end
    local id = ns.Folders.Create(spec.name(), role == "addons" and not ns.Folders.Default(), role)
    settle(ns.Folders.Get(id), spec)
    place(id, spec)
    if spec.overflow then
        ns.Folders.SetOverflow(id, true)
    end
    ns.Folders.Refresh(id)
    Hub.Changed()
    return id
end
