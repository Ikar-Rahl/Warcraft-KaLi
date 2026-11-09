-- The game side of the model: the real tracked list, its events, login reconciliation and auto-tracking.
local _, ns = ...

local Tracking = {}
ns.Tracking = Tracking

local function log(fmt, ...)
    ns.Debug.Log("tracking", fmt, ...)
end

-- The model's view of the game.
local World = {}
Tracking.World = World

function World:IsWatched(questID)
    return C_QuestLog.GetQuestWatchType(questID) ~= nil
end

-- The game's list without task and bounty quests, which Blizzard's own auto-tracking skips too.
function World:WatchedList()
    local list = {}
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if id and not C_QuestLog.IsQuestTask(id) and not C_QuestLog.IsQuestBounty(id) then
            list[#list + 1] = id
        end
    end
    return list
end

function World:AddWatch(questID)
    local ok = C_QuestLog.AddQuestWatch(questID)
    log("AddQuestWatch(%d) -> %s", questID, tostring(ok))
    return ok
end

-- Blizzard's own check, which refuses in the New Player Experience.
function World:CanRemoveWatch()
    return not (QuestUtil and QuestUtil.CanRemoveQuestWatch) or QuestUtil.CanRemoveQuestWatch()
end

function World:RemoveWatch(questID)
    if not self:CanRemoveWatch() then
        log("RemoveQuestWatch(%d) refused by CanRemoveQuestWatch", questID)
        return false
    end
    local ok = C_QuestLog.RemoveQuestWatch(questID)
    log("RemoveQuestWatch(%d) -> %s", questID, tostring(ok))
    return ok
end

function World:InCombat()
    return InCombatLockdown()
end

function World:HasQuest(questID)
    return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
end

local function isDone(questID)
    return C_QuestLog.IsQuestFlaggedCompleted(questID) and not C_QuestLog.IsRepeatableQuest(questID)
end

-- The NPC showing the quest frame, or nil. A secret value can't be compared, so it counts as none.
local function questNpc()
    local guid = UnitGUID("questnpc") or UnitGUID("npc")
    if guid == nil or (issecretvalue and issecretvalue(guid)) then
        return nil
    end
    return guid
end

-- Auto-tracking follows this character's choice, off by default, Ikar's ruling. The game's own value is put
-- back at logout, so removing the addon leaves the game as it was. The game's copy of its settings can arrive
-- after login and overwrite the choice, so it's applied again then. Once they've arrived, a change made outside
-- the addon, with /console or by another addon, becomes the choice.
local applied -- the value this addon last wrote
local variablesLoaded, cvarsLoaded = false, false
local pendingOriginal -- the value found on the first login, until the game's copy is known

function Tracking.ApplyAutoQuestWatch()
    local db = ns.db
    local current = GetCVar("autoQuestWatch")
    if db.autoQuestWatchOriginal == nil and pendingOriginal == nil then
        if cvarsLoaded then
            db.autoQuestWatchOriginal = current or "1"
        else
            pendingOriginal = current or "1"
        end
    end
    applied = db.options.autoQuestWatch and "1" or "0"
    if current ~= applied then
        local ok = SetCVar("autoQuestWatch", applied)
        log("SetCVar autoQuestWatch %s -> %s", applied, tostring(ok))
    end
end

function Tracking.SetAutoQuestWatch(on)
    ns.db.options.autoQuestWatch = on and true or false
    Tracking.ApplyAutoQuestWatch()
end

local function onCVarsLoaded()
    cvarsLoaded = true
    if pendingOriginal then
        local current = GetCVar("autoQuestWatch")
        -- Anything but this addon's own value came from the game's copy, so it's the player's.
        ns.db.autoQuestWatchOriginal = current ~= applied and current or pendingOriginal
        pendingOriginal = nil
    end
    Tracking.ApplyAutoQuestWatch()
end

ns.On("VARIABLES_LOADED", function()
    variablesLoaded = true
    if ns.model then
        onCVarsLoaded()
    end
end)

local function onCVarUpdate(_, name, value)
    if not cvarsLoaded or type(name) ~= "string" or name:lower() ~= "autoquestwatch" then
        return
    end
    value = value ~= nil and tostring(value) or GetCVar("autoQuestWatch")
    if value ~= applied then
        applied = value
        ns.db.options.autoQuestWatch = value == "1"
        log("autoQuestWatch changed outside the addon: %s", value)
        ns.RequestRefresh()
    end
end

local function restoreAutoQuestWatch()
    local original = ns.db and (ns.db.autoQuestWatchOriginal or pendingOriginal)
    if original and GetCVar("autoQuestWatch") ~= original then
        applied = original
        SetCVar("autoQuestWatch", original)
    end
end

local function settle()
    if ns.model:SettleWatches() then
        ns.RequestRefresh()
    end
end

local function noteRepeatable()
    ns.model:NoteRepeatable((ns.QuestLog.Read(ns.categories.Classify)))
end

-- Reconciles once the log has something in it, since it can read as empty during login.
local function reconcile()
    if ns.model.watched or InCombatLockdown() then
        return
    end
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    if (numQuests or 0) == 0 then
        return
    end
    local quests, order = ns.QuestLog.Read(ns.categories.Classify)
    ns.model:NoteRepeatable(quests)
    ns.model:Reconcile(order)
    local forgotten = ns.model:ForgetDone(isDone)
    log("reconciled %d quests, forgot %d done", #order, forgotten)
    ns.Later("settle", settle)
    ns.RequestRefresh()
end

-- The NPC who offered or took each quest, for the follow-up rule, and quests just turned in.
local offeredBy, takenBy, turnedIn = {}, {}, {}

function Tracking.Start()
    ns.model = ns.Model.New(ns.db, World, ns.G("QUESTS_LABEL", "Quêtes"))
    cvarsLoaded = variablesLoaded
    Tracking.ApplyAutoQuestWatch()

    -- The payload isn't used: the settle compares the whole list.
    ns.On("QUEST_WATCH_LIST_CHANGED", function()
        ns.Later("settle", settle)
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        reconcile()
        settle()
    end)
    ns.On("QUEST_LOG_UPDATE", function()
        reconcile()
        ns.RequestRefresh()
    end)
    ns.On("QUEST_DETAIL", function()
        local id = GetQuestID()
        if id and id ~= 0 then
            offeredBy[id] = questNpc()
        end
    end)
    ns.On("QUEST_COMPLETE", function()
        local id = GetQuestID()
        if id and id ~= 0 then
            takenBy[id] = questNpc()
        end
    end)
    ns.On("QUEST_ACCEPTED", function(_, questID)
        local how = ns.model:OnAccepted(questID, offeredBy[questID], GetTime())
        offeredBy[questID] = nil
        log("accepted %s: %s", tostring(questID), tostring(how))
        ns.Later("repeatable", noteRepeatable)
        ns.RequestRefresh()
    end)
    ns.On("QUEST_TURNED_IN", function(_, questID)
        ns.model:OnTurnedIn(questID, C_QuestLog.IsRepeatableQuest(questID), takenBy[questID], GetTime())
        takenBy[questID] = nil
        turnedIn[questID] = true
        ns.RequestRefresh()
    end)
    -- A quest gone from the log with no turn-in was abandoned. The turn-in can come just after, so it waits a moment.
    ns.On("QUEST_REMOVED", function(_, questID)
        if type(questID) ~= "number" then
            return
        end
        C_Timer.After(1, function()
            ns.SafeCall(function()
                local turned = turnedIn[questID]
                turnedIn[questID] = nil
                if not turned and not World:HasQuest(questID) and ns.model:OnAbandoned(questID) then
                    ns.RequestRefresh()
                end
            end)
        end)
    end)
    ns.On("CVAR_UPDATE", onCVarUpdate)
    ns.On("PLAYER_LOGOUT", restoreAutoQuestWatch)
    reconcile()
end
