-- The area highlight, "Signaler les quêtes de la zone": a quest whose area you're in brightens and gains an arrow,
-- and every bar and group holding it counts how many are here. Coming into an area glows once. Nothing moves. The
-- signals, best first, are organiser-design.md's (Area highlight); a one-second check runs only while it's on.
local _, ns = ...
local L = ns.L

local Area = {}
ns.Area = Area

local RANGE = 300 -- yards, for the three signals that measure
local RANGE_SQ = RANGE * RANGE
Area.SIGNALS = { "blob", "pin", "distance", "spot" }

local quests = {} -- questID -> { title, complete } from the last layout
local here = {} -- questID -> the first signal that answered
local entered = {} -- questID -> true: came into its area since the last layout, to glow once
local primed = false -- the first check only notes what's here, so a login or switching it on glows nothing
local ticker
local watching = false

local function wanted()
    return ns.db ~= nil and ns.db.options.areaHighlight ~= false and ns.Tracker.IsActive()
end

-- A point of a map in the world's yards, or nil where the game won't say, as in instances.
local function world(mapID, x, y)
    if not (mapID and x and y) then
        return nil
    end
    local continent, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if continent and pos then
        local wx, wy = pos:GetXY()
        return { continent = continent, x = wx, y = wy }
    end
end

local function near(a, b)
    if not (a and b) or a.continent ~= b.continent then
        return false
    end
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy <= RANGE_SQ
end

-- The player's map and place on it, or only the map, or nothing.
local function playerOnMap()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local x, y = pos:GetXY()
        return mapID, x, y
    end
    return mapID
end

local function signalOf(id, q, pins, player)
    if C_Minimap.IsInsideQuestBlob(id) then
        return "blob"
    end
    if near(pins[id], player) then
        return "pin"
    end
    local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(id)
    if distanceSq and onContinent ~= false and distanceSq <= RANGE_SQ then
        return "distance"
    end
    -- Where it last progressed only says where to go while it isn't done: once done, the turn-in is elsewhere.
    local spot = not q.complete and ns.db.spots[id]
    if spot and near(world(spot[1], spot[2], spot[3]), player) then
        return "spot"
    end
end

-- Reads every signal for the quests of the last layout. A change redraws; quests newly here glow at that redraw.
function Area.Check()
    if not wanted() then
        return
    end
    local mapID, x, y = playerOnMap()
    local player = world(mapID, x, y)
    local pins = {}
    if player then
        for _, info in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
            pins[info.questID] = world(mapID, info.x, info.y)
        end
    end
    local now, changed = {}, false
    for id, q in pairs(quests) do
        now[id] = signalOf(id, q, pins, player)
        if now[id] and not here[id] then
            changed = true
            entered[id] = primed or nil
        end
    end
    for id in pairs(here) do
        changed = changed or not now[id]
    end
    here = now
    primed = true
    if changed then
        ns.RequestRefresh()
    end
end

-- Starts or stops the check, following the option and the tracker. Stopped, nothing is here.
function Area.Apply()
    if not watching then
        watching = true
        ns.On("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED", function()
            ns.Later("area", Area.Check)
        end)
        ns.On("ZONE_CHANGED_NEW_AREA", function()
            ns.Later("area", Area.Check)
        end)
        ns.On("QUEST_REMOVED", function(_, questID)
            if ns.db and questID then
                ns.db.spots[questID] = nil
            end
        end)
    end
    if wanted() then
        if not ticker then
            primed = false
            ticker = C_Timer.NewTicker(1, function()
                ns.SafeCall(Area.Check)
            end)
            ns.Later("area", Area.Check)
        end
    elseif ticker or next(here) then
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        wipe(here)
        wipe(entered)
        ns.RequestRefresh()
    end
end

-- From each layout: the quests in the log, and those whose objectives just moved, which learn where the player is.
function Area.Note(log, progressed)
    wipe(quests)
    for id, q in pairs(log) do
        quests[id] = { title = q.title, complete = q.complete }
    end
    for id in pairs(here) do
        if not log[id] then
            here[id], entered[id] = nil, nil
        end
    end
    if not (ns.db and ns.db.options.areaHighlight ~= false) or not next(progressed or {}) then
        return
    end
    local mapID, x, y = playerOnMap()
    if not x then
        return
    end
    x, y = math.floor(x * 10000 + 0.5) / 10000, math.floor(y * 10000 + 0.5) / 10000
    for id in pairs(progressed) do
        ns.db.spots[id] = { mapID, x, y }
    end
end

-- The signal that puts a quest here, or nil.
function Area.Is(id)
    return here[id]
end

-- How many of a header's quests are here.
function Area.Count(list)
    local n = 0
    for _, q in ipairs(list or {}) do
        if here[q.id] then
            n = n + 1
        end
    end
    return n
end

-- After a layout: each quest that came into its area glows once, its row if drawn, else the nearest header above it.
function Area.PlayEntered(rowOf, headerOf)
    for id in pairs(entered) do
        local row = rowOf(id)
        if row then
            ns.Motion.FlashRow(row)
        else
            ns.Motion.Flash(headerOf(id))
        end
    end
    wipe(entered)
end

-- For the debug panel: on or off, and each quest here with its signal.
function Area.Status()
    local out = {}
    for id, signal in pairs(here) do
        out[#out + 1] = { title = quests[id] and quests[id].title or tostring(id), signal = L["AREA_" .. signal:upper()] }
    end
    table.sort(out, function(a, b)
        return ns.TextLess(a.title, b.title)
    end)
    return out, ticker ~= nil
end
