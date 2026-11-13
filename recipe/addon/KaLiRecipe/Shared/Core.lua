-- Copied from shared/addon/Core.lua by tools/sync_shared.py: edit the source, not this copy.
-- The namespace's core, shared by the KaLi addons: events, guarded calls, deferred work, chat, the combat refusal, and
-- what saved data needs (finite numbers, copies). The addon's own Core/Init.lua loads first and says who it is
-- (ns.TITLE, ns.SHORT, ns.SLASH); everything else hangs from ns. ns.G, the game's strings, is its Locale.lua's.
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"

-- The account-wide saved table for debugging, <Addon>DevDB, once the game has loaded it.
function ns.DevDB()
    return _G[ADDON .. "DevDB"]
end

-- Events: one frame, any number of handlers per event, each run guarded so one failure can't stop the others.
local handlers = {}
-- Frames start without a parent: SmartNavigationMixin hooks CreateFrame and rebuilds the caller's button groups.
local eventFrame = CreateFrame("Frame", nil, nil)

function ns.On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

function ns.Off(event, fn)
    local list = handlers[event]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == fn then
            table.remove(list, i)
        end
    end
    if #list == 0 then
        handlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

local eventCounts = {} -- since login, for the diagnostics and the report

function ns.EventCounts()
    return eventCounts
end

function ns.Fire(event, ...)
    local list = handlers[event]
    if not list then
        return
    end
    eventCounts[event] = (eventCounts[event] or 0) + 1
    if ns.Debug then
        ns.Debug.TraceEvent(event, ...)
    end
    -- A copy, so a handler that removes itself doesn't skip the next one.
    local copy = { unpack(list) }
    for i = 1, #copy do
        ns.SafeCall(copy[i], event, ...)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    ns.Fire(event, ...)
end)

-- A game function that may be missing from this client or fail on odd input: its first three results, or nothing.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end
end

function ns.Say(msg)
    print("|cffffd200" .. ns.TITLE .. " :|r " .. tostring(msg))
end

-- Runs fn and reports an error instead of letting it escape. Returns ok, then fn's results.
function ns.SafeCall(fn, ...)
    local n = select("#", ...)
    local args = { ... }
    return xpcall(function()
        return fn(unpack(args, 1, n))
    end, function(err)
        if ns.Debug then
            ns.Debug.Error(err, debugstack and debugstack(2) or debug.traceback())
        end
        return err
    end)
end

-- Work asked for many times in one frame runs once, on the next frame.
local pending = {}
function ns.Later(key, fn)
    if pending[key] then
        return
    end
    pending[key] = true
    C_Timer.After(0, function()
        pending[key] = nil
        ns.SafeCall(fn)
    end)
end

-- In a fight the game's windows don't open from an addon: true then, with the game's own error line, so the click
-- says why instead of doing nothing.
function ns.CombatRefused()
    if not InCombatLockdown() then
        return false
    end
    if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
        UIErrorsFrame:AddExternalErrorMessage(ns.G("ERR_NOT_IN_COMBAT", "In combat"))
    end
    return true
end

-- ---------- Saved data ----------

-- A number a saved file can hold, read from how it prints, not by comparing it: the game's Lua compares nan as equal
-- to itself and to everything (KaLi Recipe's /kr test in game, 2026-11-10), so `v == v` and `v < math.huge` let it
-- through. A finite number prints with digits, a point, e and signs only; nan and inf print with letters or # ("nan",
-- "-nan(ind)", "inf", "1.#INF", "-1.#IND"), whatever the C library. The offline checks fail a value compared with
-- itself in the addons' code.
function ns.Finite(v)
    return type(v) == "number" and not tostring(v):find("[^%d%.,eE%+%-]")
end
local finite = ns.Finite

-- A copy all the way down; a table met twice is copied once.
function ns.DeepCopy(v, seen)
    if type(v) ~= "table" then
        return v
    end
    seen = seen or {}
    if seen[v] then
        return seen[v]
    end
    local copy = {}
    seen[v] = copy
    for k, val in pairs(v) do
        copy[ns.DeepCopy(k, seen)] = ns.DeepCopy(val, seen)
    end
    return copy
end

-- How many keys a table holds; 0 for anything else.
function ns.Count(t)
    local n = 0
    if type(t) == "table" then
        for _ in pairs(t) do
            n = n + 1
        end
    end
    return n
end

-- Before the game writes a saved table: a number it can't write back as one (nan, inf), as a key or a value, would
-- make the whole file unreadable, so none stays, all the way down. Returns how many were taken out.
function ns.DropNonFinite(t, seen)
    seen = seen or {}
    if type(t) ~= "table" or seen[t] then
        return 0
    end
    seen[t] = true
    local n = 0
    for k, v in pairs(t) do
        if (type(k) == "number" and not finite(k)) or (type(v) == "number" and not finite(v)) then
            t[k] = nil
            n = n + 1
        elseif type(v) == "table" then
            n = n + ns.DropNonFinite(v, seen)
        end
    end
    return n
end
