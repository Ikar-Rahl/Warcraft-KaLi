-- Slash commands: /kq and /kaliquest. Inspect and drive the core without the tracker's UI, and debug it.
local _, ns = ...
local L = ns.L

local say, refused, serialize = ns.Say, ns.Refused, ns.Serialize

local function onOff(v)
    return v and L.ON or L.OFF
end

local function readLog()
    return ns.QuestLog.Read(ns.categories.Classify)
end

local function statusText()
    local version, build, _, interface = GetBuildInfo()
    local db = ns.db
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    local inGroups, offList = 0, 0
    for _, g in ipairs(db and db.groups or {}) do
        for _, q in ipairs(g.quests) do
            inGroups = inGroups + 1
            if ns.Tracking.World:HasQuest(q) and not ns.Tracking.World:IsWatched(q) then
                offList = offList + 1
            end
        end
    end
    local errors = 0
    for _ in pairs(KaLiQuestDevDB and KaLiQuestDevDB.errors or {}) do
        errors = errors + 1
    end
    local lines = {
        string.format("%s %s, client %s (%s), interface %s, %s", ns.TITLE, ns.VERSION, version, build, interface, ns.LOCALE),
        "saved data: " .. (ns.disabled and ("refused, " .. ns.disabled) or ("version " .. db.version .. (ns.firstRun and ", first run" or ""))),
        string.format("log: %d quests, game tracks %d", numQuests or 0, C_QuestLog.GetNumQuestWatches()),
        string.format("groups: %d, quests in them: %d, past the game's limit: %d", db and #db.groups or 0, inGroups, offList),
        string.format("autoQuestWatch: option %s, game %s, original %s", tostring(db and db.options.autoQuestWatch), tostring(GetCVar("autoQuestWatch")), tostring(db and db.autoQuestWatchOriginal)),
        "login reconciled: " .. tostring(ns.model ~= nil and ns.model.watched ~= nil),
        string.format("tracker: option %s, shown %s, Blizzard's sections parked %s", tostring(db and db.options.tracker), tostring(ns.Tracker.IsActive()), tostring(ns.Host.IsParked())),
        string.format("debug %s, events %s, chat %s, log lines %d, distinct errors %d", tostring(ns.Debug.Enabled()), tostring(KaLiQuestDevDB.events), tostring(KaLiQuestDevDB.chat), #KaLiQuestDevDB.log, errors),
        "combat: " .. tostring(InCombatLockdown()),
    }
    return table.concat(lines, "\n")
end

local function groupsText()
    local db = ns.db
    if #db.groups == 0 then
        return L.NO_GROUPS
    end
    local quests = readLog()
    local lines = {}
    for i, g in ipairs(db.groups) do
        lines[#lines + 1] = string.format("%d. [%d] %s (%d)%s", i, g.id, g.name, #g.quests, db.open.groups[g.id] and "  open" or "")
        for _, id in ipairs(g.quests) do
            local q = quests[id]
            local watched = ns.Tracking.World:IsWatched(id)
            lines[#lines + 1] = string.format("    #%d %s%s", id, q and q.title or "(not in the log)", (q and not watched) and "  (" .. L.PAST_LIMIT_SHORT .. ")" or "")
        end
    end
    if ns.model.deleted then
        lines[#lines + 1] = string.format(L.DELETED, ns.model.deleted.group.name) .. "  /kq group undo"
    end
    return table.concat(lines, "\n")
end

local function treeText()
    local quests, order = readLog()
    local tree = ns.Tree.Build(quests, order, ns.db.groups, GetZoneText(), ns.db.categoryOrder)
    return ns.Tree.Text(tree, function(id)
        return ns.Tracking.World:IsWatched(id)
    end)
end

local function dumpText(questID)
    local out = { "questID = " .. questID }
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    out[#out + 1] = "logIndex = " .. tostring(index)
    if index then
        out[#out + 1] = "GetInfo:"
        serialize(C_QuestLog.GetInfo(index), "    ", out)
    end
    local quests = readLog()
    if quests[questID] then
        out[#out + 1] = "record:"
        serialize(quests[questID], "    ", out)
    end
    out[#out + 1] = "GetQuestTagInfo:"
    serialize(C_QuestLog.GetQuestTagInfo(questID) or "nil", "    ", out)
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        out[#out + 1] = "classification = " .. tostring(C_QuestInfoSystem.GetQuestClassification(questID))
    end
    out[#out + 1] = "watchType = " .. tostring(C_QuestLog.GetQuestWatchType(questID))
    out[#out + 1] = "repeatable = " .. tostring(C_QuestLog.IsRepeatableQuest(questID))
    out[#out + 1] = "pushable = " .. tostring(C_QuestLog.IsPushableQuest(questID))
    out[#out + 1] = "objectives:"
    serialize(C_QuestLog.GetQuestObjectives(questID) or {}, "    ", out)
    local g = ns.model:GroupOf(questID)
    out[#out + 1] = "group = " .. (g and (g.id .. " " .. g.name) or "none")
    return table.concat(out, "\n")
end

local function runTests()
    local loaded, reason = C_AddOns.LoadAddOn("KaLiQuest_Tests")
    if not loaded or not KaLiQuestTests then
        say(string.format(L.TESTS_MISSING, tostring(reason)))
        return
    end
    local report = KaLiQuestTests.Run()
    KaLiQuestDevDB.lastTests = { when = date("%Y-%m-%d %H:%M:%S"), version = ns.VERSION, summary = report.summary, text = report.text }
    say(report.summary)
    ns.Debug.ShowText("tests", report.text)
end

-- For the bug report.
ns.Commands = { StatusText = statusText, GroupsText = groupsText, TreeText = treeText }

local COMMANDS = {}

COMMANDS.status = function()
    ns.Debug.ShowText("status", statusText())
end
COMMANDS.groups = function()
    ns.Debug.ShowText("groups", groupsText())
end
COMMANDS.tree = function()
    ns.Debug.ShowText("tree", treeText())
end
COMMANDS.dump = function(rest)
    local id = tonumber(rest)
    if id then
        ns.Debug.ShowText("#" .. id, dumpText(id))
    else
        say(L.DUMP_USAGE)
    end
end
COMMANDS.group = function(rest)
    local action, args = rest:match("^([^ \t]*)[ \t]*(.-)$")
    local ok, reason
    if action == "new" then
        ok, reason = ns.model:CreateGroup(args ~= "" and args or L.NEW_GROUP)
    elseif action == "rename" then
        local id, name = args:match("^(%d+)[ \t]+(.+)$")
        ok, reason = ns.model:RenameGroup(tonumber(id), name)
    elseif action == "del" then
        ok, reason = ns.model:DeleteGroup(tonumber(args))
    elseif action == "undo" then
        ok, reason = ns.model:UndoDelete()
    else
        say(L.UNKNOWN_COMMAND)
        return
    end
    if reason == "missing" then
        reason = string.format(L.UNKNOWN_GROUP, args)
    end
    if ok then
        say(L.DONE)
        ns.RequestRefresh()
    else
        refused(reason)
    end
end
COMMANDS.move = function(rest)
    local questID, groupID = rest:match("^(%d+)[ \t]+(%d+)$")
    questID, groupID = tonumber(questID), tonumber(groupID)
    if not questID then
        say(L.UNKNOWN_COMMAND)
        return
    end
    -- Taking out (0) also works for a quest no longer in the log, to clear it from a group.
    if groupID ~= 0 and not ns.Tracking.World:HasQuest(questID) then
        say(string.format(L.NOT_IN_LOG, questID))
        return
    end
    local ok, reason = ns.model:MoveQuest(questID, groupID ~= 0 and groupID or nil)
    if ok then
        say(L.DONE)
        ns.RequestRefresh()
    else
        refused(reason == "missing" and string.format(L.UNKNOWN_GROUP, groupID) or reason)
    end
end
COMMANDS.autotrack = function(rest)
    if rest == "on" or rest == "off" then
        ns.Tracking.SetAutoQuestWatch(rest == "on")
    end
    say(string.format(L.AUTOTRACK, onOff(ns.db.options.autoQuestWatch)))
end
-- The way back to Blizzard's own tracker, kept per character. On also takes over any section filled right now.
COMMANDS.tracker = function(rest)
    if rest == "on" then
        ns.db.options.tracker = true
        ns.Coverage.Resume()
    elseif rest == "off" then
        ns.db.options.tracker = false
        ns.Tracker.SetEnabled(false)
    end
    say(string.format(L.TRACKER, onOff(ns.db.options.tracker)))
end
COMMANDS.diag = function()
    ns.DebugPanel.Toggle()
end
COMMANDS.report = function()
    ns.Report.Open()
end
COMMANDS.alert = function()
    ns.Coverage.Simulate(not ns.Coverage.Simulating())
end
COMMANDS.debug = function(rest)
    local d = KaLiQuestDevDB
    if rest == "on" or rest == "off" then
        d.debug = rest == "on"
    elseif rest == "events" then
        d.events = not d.events
    elseif rest == "chat" then
        d.chat = not d.chat
    end
    say(string.format(L.DEBUG, onOff(d.debug), onOff(d.events), onOff(d.chat)))
end
COMMANDS.log = function()
    ns.Debug.ShowText("log", ns.Debug.LogText())
end
COMMANDS.errors = function()
    ns.Debug.ShowText("errors", ns.Debug.ErrorsText())
end
COMMANDS.clear = function()
    ns.Debug.Clear()
    say(L.DONE)
end
COMMANDS.test = runTests
COMMANDS.options = function()
    ns.Options.Open()
end

-- Commands that read or write the layout wait until the saved data has loaded and been accepted.
local NEEDS_DB = { status = false, debug = false, log = false, errors = false, clear = false, test = false, diag = false,
    report = false }

SLASH_KALIQUEST1 = "/kq"
SLASH_KALIQUEST2 = "/kaliquest"
SlashCmdList.KALIQUEST = function(input)
    local cmd, rest = (input or ""):match("^[ \t]*([^ \t]*)[ \t]*(.-)[ \t]*$")
    cmd = cmd:lower()
    local fn = COMMANDS[cmd]
    if not fn then
        for _, line in ipairs(L.HELP) do
            say(line)
        end
        return
    end
    if NEEDS_DB[cmd] ~= false and not (ns.db and ns.model) then
        say(string.format(L.DB_REFUSED, tostring(ns.disabled)))
        return
    end
    ns.SafeCall(fn, rest)
end
