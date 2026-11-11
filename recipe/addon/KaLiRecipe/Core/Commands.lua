-- KaLi Recipe's slash commands, /kr and /kalirecipe, on the shared dispatcher (Shared/Commands.lua, with the commands
-- for debugging): the notebook, the options, and what the addon knows.
local _, ns = ...
local L = ns.L

local say = ns.Say

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

local function statusText()
    local version, build, _, interface = GetBuildInfo()
    local db = ns.db
    local d = KaLiRecipeDevDB or {}
    local sightings = 0
    for _, list in pairs(db and db.sightings or {}) do
        sightings = sightings + #list
    end
    local s = ns.Scan
    local ah = s and s.ah or {}
    local trainer = s and s.trainerStats or {}
    local lines = {
        string.format("%s %s, client %s (%s), interface %s, %s, data %s", ns.TITLE, ns.VERSION, version, build, interface, ns.LOCALE,
            tostring(ns.DATA_BUILD)),
        "saved data: " .. (ns.disabled and ("refused, " .. ns.disabled) or ("version " .. db.version .. (ns.firstRun and ", first run" or "") ..
            (ns.dbInfo.restored and ", restored from this character's copy" or "") .. ", set aside " .. #db.setAside .. " (/kr data)")),
        string.format("characters %d, recipes seen %d, sightings %d, in the notebook %d", count(db and db.chars), count(db and db.sightings),
            sightings, ns.book and ns.book:Total() or 0),
        string.format("trainer services: recipes by tooltip %d, by item %d, by name %d; not recipes %d; unknown %d", trainer.tooltip or 0,
            trainer.product or 0, trainer.name or 0, trainer.other or 0, trainer.none or 0),
        string.format("auction house: queried %s, answered %s, refused %s", tostring(ah.queried), tostring(ah.answered), tostring(ah.refused)),
        string.format("recipe items not in the data this session: %d", count(ns.Game.unknownRecipeItems)),
        string.format("notebook shown %s, docked %s, follow %s, tooltips %s, Baganator %s", tostring(ns.Notebook.IsShown()),
            tostring(ns.Follow.IsDocked()), tostring(db and db.options.follow), tostring(ns.tooltipsOn), tostring(ns.Markers.baganator)),
        string.format("debug %s, events %s, chat %s, log lines %d, distinct errors %d", tostring(ns.Debug.Enabled()), tostring(d.events),
            tostring(d.chat), #(d.log or {}), count(d.errors)),
        "combat: " .. tostring(InCombatLockdown()),
    }
    return table.concat(lines, "\n")
end

-- The notebook in numbers, for the report: characters are counted, never named.
local function notebookText()
    local m = ns.book
    local lines = {}
    for i, key in ipairs(m:CharKeys()) do
        local c = m:Char(key)
        local profs = {}
        for _, skill in ipairs(m:ProfsOf(key)) do
            profs[#profs + 1] = string.format("%d:%d/%d", skill, m:Rank(key, skill), m:MaxRank(key, skill))
        end
        lines[#lines + 1] = string.format("character %d%s: %s; knows %d; recipe items bags %d, bank %d%s", i, key == m.me and " (this one)" or "",
            #profs > 0 and table.concat(profs, " ") or "no profession", count(c.known), count(c.bags), count(c.bank),
            c.bankSeen and "" or ", bank never opened")
    end
    local skills = {}
    for skill in pairs(ns.PROFESSION_ICONS) do
        skills[#skills + 1] = skill
    end
    table.sort(skills)
    for _, skill in ipairs(skills) do
        local split = m:Split(m.me, skill)
        local kinds = {}
        for _, spell in ipairs(m:SpellsOf(skill)) do
            for _, s in ipairs(m:Sightings(spell)) do
                kinds[s.k] = (kinds[s.k] or 0) + 1
            end
        end
        local k = {}
        for kind, n in pairs(kinds) do
            k[#k + 1] = kind .. " " .. n
        end
        table.sort(k)
        if #m:SpellsOf(skill) > 0 then
            lines[#lines + 1] = string.format("skill %d: to learn %d, seen %d, learned %d; sightings %s", skill, #split.learn, #split.seen,
                #split.known, #k > 0 and table.concat(k, ", ") or "none")
        end
    end
    return table.concat(lines, "\n")
end

local function seenText()
    local m = ns.book
    local lines = {}
    local spells = {}
    for spell in pairs(ns.db.sightings) do
        spells[#spells + 1] = spell
    end
    table.sort(spells, function(a, b)
        return ns.TextLess(m:Name(a), m:Name(b))
    end)
    for _, spell in ipairs(spells) do
        -- A recipe a later data no longer holds is still listed, so /kr forget can take it off.
        local info = m:Info(spell)
        lines[#lines + 1] = string.format("#%d %s [%s, %s]", spell, m:Name(spell), info and ns.Game.ProfName(info.skill) or "?", m:State(spell))
        for _, s in ipairs(m:Sightings(spell)) do
            lines[#lines + 1] = "    " .. ns.Text.Where(m, s) .. " · " .. ns.Text.Date(s.t) .. (s.x and string.format(" (%.1f, %.1f)", s.x * 100, s.y * 100) or "")
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end

local function when(t)
    return type(t) == "number" and date("%Y-%m-%d %H:%M", t) or "never"
end

-- The saved data's state, for /kr data and the report: its format and dates, what it holds, what was kept from a later
-- version or set aside, this character's copy, and the notebook's last events. Numbers only, no name.
local function dataText()
    local db, info = ns.db, ns.dbInfo or {}
    if not db then
        return "saved data refused, left untouched: " .. tostring(ns.disabled)
    end
    local DB = ns.DB
    local meta = db.meta
    local sightings, later = 0, 0
    for _, list in pairs(db.sightings) do
        for _, s in ipairs(list) do
            sightings = sightings + 1
            if not DB.KINDS[s.k] then
                later = later + 1
            end
        end
    end
    local changed, unknown = 0, 0
    for key, v in pairs(db.options) do
        if DB.DEFAULTS[key] == nil then
            unknown = unknown + 1
        elseif v ~= DB.DEFAULTS[key] then
            changed = changed + 1
        end
    end
    local lines = {
        string.format("format %d, notebook %s, created %s", db.version, tostring(meta.id), when(meta.created)),
        string.format("last written by %s on %s", tostring(meta.writer or "nothing yet"), when(meta.written)),
        string.format("recipes seen %d, sightings %d (kept from a later version %d), characters %d, recipes forgotten %d",
            count(db.sightings), sightings, later, count(db.chars), count(db.forgotten)),
        string.format("options changed %d, options of a later version kept %d", changed, unknown),
        string.format("set aside %d%s", #db.setAside, meta.setAsideDropped and (", oldest dropped " .. meta.setAsideDropped) or ""),
    }
    for i = math.max(1, #db.setAside - 4), #db.setAside do
        local e = db.setAside[i]
        lines[#lines + 1] = string.format("    %s %s: %s", when(e.t), tostring(e.at), tostring(e.why))
    end
    lines[#lines + 1] = string.format("this session: repaired %d, set aside %d, %s", info.fixed or 0, info.setAside or 0,
        info.restored and "restored from this character's copy" or ("from this character's copy " .. (info.recovered or 0)))
    if info.copyRefused then
        lines[#lines + 1] = "this character's copy: unreadable, left as it is: " .. tostring(info.copyRefused)
    elseif info.copy then
        lines[#lines + 1] = string.format("this character's copy: written %s by %s, %d recipes", when(info.copy.at), tostring(info.copy.writer),
            info.copy.recipes)
    else
        lines[#lines + 1] = "this character's copy: none yet, written at logout"
    end
    lines[#lines + 1] = "history:"
    for i = math.max(1, #meta.history - 9), #meta.history do
        local e = meta.history[i]
        local fields = {}
        for k, v in pairs(e) do
            if k ~= "t" and k ~= "what" and k ~= "by" then
                fields[#fields + 1] = k .. " " .. tostring(v)
            end
        end
        table.sort(fields)
        lines[#lines + 1] = string.format("    %s %s (%s)%s", when(e.t), tostring(e.what), tostring(e.by),
            #fields > 0 and (": " .. table.concat(fields, ", ")) or "")
    end
    return table.concat(lines, "\n")
end

local function charText()
    local m = ns.book
    local c = m:Char(m.me)
    if not c then
        return "(not read yet)"
    end
    local out = {}
    ns.Serialize({ profs = c.profs, maxRanks = c.maxRanks, bags = c.bags, bank = c.bank, known = count(c.known), class = c.class }, "", out)
    return table.concat(out, "\n")
end

-- A recipe by its number, or by its name among those noted.
local function findSpell(text)
    local id = tonumber(text)
    if id then
        return id
    end
    local folded = ns.Fold(text)
    for spell in pairs(ns.db.sightings) do
        if ns.Fold(ns.book:Name(spell)) == folded then
            return spell
        end
    end
end

-- For /status and the bug report.
local Commands = ns.Commands
Commands.StatusText, Commands.NotebookText, Commands.DataText = statusText, notebookText, dataText

local COMMANDS = {}
COMMANDS[""] = function()
    ns.Notebook.Toggle()
end
COMMANDS.help = function()
    for _, line in ipairs(L.HELP) do
        say(line)
    end
end
COMMANDS.options = function()
    ns.Options.Open()
end
COMMANDS.status = function()
    ns.Debug.ShowText("status", statusText())
end
COMMANDS.seen = function()
    ns.Debug.ShowText("seen", seenText())
end
COMMANDS.data = function()
    ns.Debug.ShowText("data", dataText())
end
COMMANDS.char = function()
    ns.Debug.ShowText("char", charText())
end
COMMANDS.forget = function(rest)
    if rest == "" then
        say(L.FORGET_USAGE)
        return
    end
    local spell = findSpell(rest)
    if spell and ns.book:Forget(spell, time()) then
        say(string.format(L.FORGOTTEN, ns.book:Name(spell)))
        ns.Changed()
    else
        say(string.format(L.NOT_IN_NOTEBOOK, rest))
    end
end

-- Commands that read the notebook wait until the saved data has loaded and been accepted; these don't.
local ANYTIME = { help = true, status = true, data = true }
for name, fn in pairs(COMMANDS) do
    Commands.Add(name, fn, ANYTIME[name])
end

Commands.Register("KALIRECIPE", { "/kr", "/kalirecipe" }, {
    ready = function()
        return ns.db and ns.book
    end,
    unknown = function()
        say(L.UNKNOWN_COMMAND)
    end,
})
