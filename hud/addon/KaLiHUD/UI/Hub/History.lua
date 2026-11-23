-- Undo and redo (Ikar 2026-11-16: "add an undo/redo stack, up to 10 actions. movement, deletion, creation"): what the
-- player does to the hub's elements, the last 10 of it, undone and done again from the bar's menu (UI/Hub/Menus.lua)
-- or a key the player binds (Bindings.xml). An action is moving an element (a drag, its menu, hiding or showing it),
-- making one (a folder, a macro, a note, a separator, a paste), deleting one, resetting one (UI/Hub/Seeds.lua) or
-- renaming a folder. Each keeps what it changed in the saved data, field by field: undoing puts those fields back as
-- they were, and only those, so what changed meanwhile apart from it (a macro's commands saved in its editor) stays;
-- doing it again puts them as they were just before the undo. For this session only; not during a fight, when the
-- bar holds still, nor while something is dragged.
local _, ns = ...

local History = {}
ns.History = History

local L = ns.L

History.MOST = 10
-- The saved tables an action changes: the options (an item's own, reset with it), where each element stands, the
-- folders, the macros, the separators, the copies (UI/Hub/Hub.lua's).
local TABLES = { "options", "items", "folders", "macros", "separators", "copies" }
-- What no action changes: whether a folder is open (the player's click, the pointer).
local VOLATILE = { folders = { opened = true } }

-- The actions done, the last one last; those undone, the last undone last.
local done, undone = {}, {}
-- Inside an action, the actions it's made of are part of it.
local depth = 0

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

local function same(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for k, x in pairs(a) do
        if not same(x, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

local function snapshot()
    local s = {}
    for _, t in ipairs(TABLES) do
        local rows, skip = {}, VOLATILE[t]
        for key, v in pairs(ns.db[t]) do
            rows[key] = copy(v, skip)
        end
        s[t] = rows
    end
    return s
end

-- What changed since `before`: { t, key, field, before, after }, a field of a row in both, else the row; nil with
-- nothing changed.
local function diff(before)
    local changes = {}
    for _, t in ipairs(TABLES) do
        local was, now, skip = before[t], ns.db[t], VOLATILE[t]
        local keys = {}
        for key in pairs(was) do
            keys[key] = true
        end
        for key in pairs(now) do
            keys[key] = true
        end
        for key in pairs(keys) do
            local a, b = was[key], now[key]
            if type(a) == "table" and type(b) == "table" then
                local fields = {}
                for f in pairs(a) do
                    fields[f] = true
                end
                for f in pairs(b) do
                    fields[f] = true
                end
                for f in pairs(fields) do
                    if not (skip and skip[f]) and not same(a[f], b[f]) then
                        changes[#changes + 1] = { t = t, key = key, field = f, before = copy(a[f]), after = copy(b[f]) }
                    end
                end
            elseif not same(a, b) then
                changes[#changes + 1] = { t = t, key = key, before = a, after = copy(b, skip) }
            end
        end
    end
    return #changes > 0 and changes or nil
end

-- What a change is now: its field, or its row.
local function current(c)
    local row = ns.db[c.t][c.key]
    if c.field == nil then
        return copy(row, VOLATILE[c.t])
    end
    return type(row) == "table" and copy(row[c.field]) or nil
end

local function put(c, v)
    local rows = ns.db[c.t]
    if c.field == nil then
        rows[c.key] = copy(v)
        return
    end
    local row = rows[c.key]
    if type(row) ~= "table" then
        -- its row gone meanwhile: made again for a value, left gone for none
        if v == nil then
            return
        end
        row = {}
        rows[c.key] = row
    end
    row[c.field] = copy(v)
end

-- What it changed drawn anew: a folder or a macro gone or back, each module told; then the whole hub.
local function redraw(changes)
    local seen = {}
    for _, c in ipairs(changes) do
        local key = c.t .. "\0" .. c.key
        if not seen[key] then
            seen[key] = true
            if c.t == "folders" then
                ns.Folders.Refresh(c.key)
            elseif c.t == "macros" then
                ns.Macros.Refresh(c.key)
            elseif c.t == "separators" then
                ns.Separators.Refresh(c.key)
            end
        end
    end
    ns.InfoBar.Forget()
    ns.Hub.Changed()
    if ns.Items and ns.Items.Update then
        ns.Items.Update()
    end
end

-- What an element is called, while there is one by that name.
local function labelOf(name)
    local e = type(name) == "string" and ns.Hub.Entry(name)
    return e and ns.Hub.Label(name, e.obj) or nil
end

-- `fn(...)` run whole or not at all: true and its first two results; or, when it raises an error, what it had changed
-- in the saved data put back as it was, each module told and the hub drawn again, the error kept with the place it
-- came from, and false. An action that failed half way left the saved data half changed, with no step to undo it by,
-- and its error named this file in place of what failed (the review of 2026-11-18); what's made once for the player
-- runs through here too (UI/Hub/Seeds.lua).
local failedAt
local function failed(err)
    failedAt = debugstack and debugstack(2) or debug.traceback()
    return err
end

local function attempt(fn, ...)
    local n, args = select("#", ...), { ... }
    local before = snapshot()
    depth = depth + 1
    local ok, a, b = xpcall(function()
        return fn(unpack(args, 1, n))
    end, failed)
    depth = depth - 1
    if ok then
        return true, a, b, before
    end
    local changes = diff(before)
    if changes then
        for i = #changes, 1, -1 do
            put(changes[i], changes[i].before)
        end
        ns.SafeCall(redraw, changes)
    end
    ns.Debug.Error(a, failedAt)
    return false
end

-- For what isn't an action of the player's, and is no step to undo: true and its first result once done, false with
-- all put back.
function History.Attempt(fn, ...)
    local ok, a = attempt(fn, ...)
    return ok, a
end

-- `fn(...)` done as one action of the player's, `kind` saying what it is (L.ACT_<kind>) and `name` which element (its
-- name before; with none, the one `fn` gives back, made by it); its results given back. Inside another, part of that
-- one. One that fails changes nothing (attempt) and gives nothing back.
function History.Do(kind, name, fn, ...)
    if depth > 0 or not ns.db then
        return fn(...)
    end
    local label = labelOf(name)
    local ok, a, b, before = attempt(fn, ...)
    if not ok then
        return
    end
    local changes = diff(before)
    if changes then
        -- the player arranged the bar: each item's place its own width again (UI/Hub/InfoBar.lua's places)
        ns.InfoBar.Forget()
        label = label or labelOf(a) or labelOf(name) or "?"
        -- element: the one acted on (the one made, for a creation), lit where an undo or a redo leaves it
        local element = type(name) == "string" and name or type(a) == "string" and a or nil
        done[#done + 1] = { text = string.format(L["ACT_" .. kind], label), changes = changes, element = element }
        if #done > History.MOST then
            table.remove(done, 1)
        end
        wipe(undone)
    end
    return a, b
end

-- What undoing and doing again would do, for the menus: their texts, nil with none.
function History.Next()
    local last, next = done[#done], undone[#undone]
    return last and last.text, next and next.text
end

-- Not during a fight (the game's line saying why) nor while something is dragged.
local function refused()
    return ns.CombatRefused() or ns.HubDrag.Current() ~= nil
end

-- The saved tables changed whole by `fn`, by none of the player's actions on the bar (a set of settings applied:
-- Core/Sets.lua): done whole or not at all, what it changed drawn anew as an undo's is, each module told, and the
-- steps to undo forgotten, which were steps of what is no longer there. True once done; false when it failed (all
-- put back) or is refused (a fight, a drag).
function History.Replace(fn)
    if refused() then
        return false
    end
    local ok, _, _, before = attempt(fn)
    if not ok then
        return false
    end
    local changes = diff(before)
    wipe(done)
    wipe(undone)
    if changes then
        ns.SafeCall(redraw, changes)
    end
    return true
end

-- The last action undone; false with none, or refused.
function History.Undo()
    local action = done[#done]
    if not action or refused() then
        return false
    end
    done[#done] = nil
    for i = #action.changes, 1, -1 do
        local c = action.changes[i]
        c.after = current(c)
        put(c, c.before)
    end
    undone[#undone + 1] = action
    redraw(action.changes)
    -- back where it was, which may be out of sight: lit there (UI/Hub/InfoBar.lua's Flash; nothing for one gone)
    ns.InfoBar.Flash(action.element)
    return true
end

-- The last undone done again; false with none, or refused.
function History.Redo()
    local action = undone[#undone]
    if not action or refused() then
        return false
    end
    undone[#undone] = nil
    for _, c in ipairs(action.changes) do
        c.before = current(c)
        put(c, c.after)
    end
    done[#done + 1] = action
    redraw(action.changes)
    ns.InfoBar.Flash(action.element)
    return true
end

-- How many there are to undo and to do again, for the tests.
function History.Count()
    return #done, #undone
end

-- For the tests: as at login.
function History.Clear()
    wipe(done)
    wipe(undone)
end

local BINDINGS = { undo = History.Undo, redo = History.Redo }

-- The game's key bindings, under KaLi HUD (Bindings.xml): undo and redo, named once the languages have loaded.
BINDING_HEADER_KALIHUD = ns.TITLE
BINDING_NAME_KALIHUD_UNDO = ns.L.BINDING_UNDO
BINDING_NAME_KALIHUD_REDO = ns.L.BINDING_REDO

-- The keys bound in the game's key bindings, under KaLi HUD (Bindings.xml).
function KaLiHUD_Binding(action)
    if ns.db and BINDINGS[action] then
        ns.SafeCall(BINDINGS[action])
    end
end
