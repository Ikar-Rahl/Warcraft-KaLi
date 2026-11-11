-- The namespace, events and deferred work. Everything else hangs from ns. Same frame as KaLi Quest's.
local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = "KaLi Recipe"
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"

-- Internal and unstable, for KaLiRecipe_Tests and debugging. Not an API for other addons.
KaLiRecipeDev = { ns = ns }

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

local eventCounts = {} -- since login, for the report

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

-- What changed in the notebook's knowledge, redrawn once per frame wherever it shows: the notebook, the count lines,
-- the markers. Each UI piece adds itself with ns.OnChange.
local listeners = {}
function ns.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function ns.Changed()
    ns.Later("changed", function()
        for _, fn in ipairs(listeners) do
            ns.SafeCall(fn)
        end
    end)
end
