-- The namespace, events and deferred work. Everything else hangs from ns.
local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = "KaLi Quest"
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"

-- Internal and unstable, for KaLiQuest_Tests and debugging. Not an API for other addons.
KaLiQuestDev = { ns = ns }

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

local eventCounts = {} -- since login, for the debug panel

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

-- A game function that may be missing from this client or fail on odd input: its first two results, or nothing.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if ok then
        return a, b
    end
end

function ns.Say(msg)
    print("|cffffd200" .. ns.TITLE .. " :|r " .. tostring(msg))
end

local REASONS = {
    combat = function()
        return ns.G("ERR_NOT_IN_COMBAT", "In combat")
    end,
    empty = function()
        return ns.L.EMPTY_NAME
    end,
    missing = function()
        return ns.L.GROUP_GONE
    end,
    npe = function()
        return ns.L.NPE_REFUSED
    end,
    nothing = function()
        return ns.L.NOTHING_TO_UNDO
    end,
}

-- Says in chat why something was refused: a reason the model gives, or any text.
function ns.Refused(reason)
    local text = REASONS[reason]
    ns.Say(text and text() or reason)
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

-- One layout per frame, however many events asked for it. ns.Refresh is set once there's something to draw.
function ns.RequestRefresh()
    ns.Later("refresh", function()
        if ns.Refresh then
            ns.Refresh()
        end
    end)
end
