-- This session and the character's record (Ikar 2026-11-16: "timer (session and afk)", "session (folder, add open
-- the cooldown settings tool)", "errors, maybe enhance it", "death", "achievements points", "statistics (folder)"):
-- how long the game has run and how long away, the errors of the session (the error addon's when there is one, the
-- actions the game blocked), the deaths of the session and of the character's statistics, the achievement points, and
-- statistics of the game's own. The session's folder holds the game's commands as macros (reload, the cooldown
-- manager, log out, quit), Blizzard's secure ones.
local _, ns = ...

local Infos, Hub, L, Format = ns.Infos, ns.Hub, ns.L, ns.Format

local SEP = ns.Seeds.SEP

-- ---------- The session ----------

local SESSION = "KaLiHUD_Session"
-- Away: since when (GetTime), and how long in all this session.
local away = { since = nil, total = 0 }

local function isAway()
    return ns.Plain(UnitIsAFK("player")) == true
end

local function awayNow()
    return away.since and (GetTime() - away.since) or 0
end

Hub.Add(SESSION, {
    type = "data source", text = "", atlas = "ChromieTime-32x32", category = "time", home = "session",
    label = L.ITEM_SESSION,
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, L.ITEM_SESSION)
        Infos.Line(tooltip, L.SESSION_TIME, Format.Duration(ns.Call(GetSessionTime) or 0))
        local since = ns.Items.MeasureSince()
        if since then
            Infos.Line(tooltip, L.MEASURE, Format.Duration(GetTime() - since))
        end
        if away.since then
            Infos.Line(tooltip, ns.G("AFK", "AFK"), Format.Duration(awayNow()))
        end
        Infos.Line(tooltip, L.SESSION_AWAY, Format.Duration(away.total + awayNow()))
        Infos.Hint(tooltip, L.SESSION_TIP)
    end,
    -- a new measure: the gold's, the experience's, the deaths' and this time's count from now (Infos.NewMeasure, below)
    menu = {
        { text = L.MEASURE_NEW, tooltip = L.MEASURE_NEW_TIP, func = function()
            Infos.NewMeasure()
        end },
    },
}, "hidden", 800)

-- Away, its text's colour: one table, so an update that changes nothing draws nothing again.
local AWAY = { 1, 0.6, 0.2 }

local function updateSession()
    local away_ = isAway()
    if away_ and not away.since then
        away.since = GetTime()
    elseif not away_ and away.since then
        away.total = away.total + awayNow()
        away.since = nil
    end
    if away.since then
        Hub.Set(SESSION, "textColor", AWAY)
        Hub.Set(SESSION, "text", ns.G("AFK", "AFK") .. " " .. Format.Duration(awayNow()))
    else
        -- since the last measure asked for, else since login
        local since = ns.Items.MeasureSince()
        Hub.Set(SESSION, "textColor", nil)
        Hub.Set(SESSION, "text", Format.Duration(since and GetTime() - since or ns.Call(GetSessionTime) or 0))
    end
end
Infos.Updates(updateSession, { "PLAYER_FLAGS_CHANGED" }, 30)

-- ---------- Errors ----------

local ERRORS = "KaLiHUD_Errors"
-- The game's blocked and forbidden actions this session, any addon's: { addon, what }, the last BLOCKED_KEPT of them
-- (an addon blocked at each of a fight's frames mustn't fill the memory), and how many there were in all.
local blocked = {}
local BLOCKED_KEPT = 50
local blockedCount = 0
-- The error addon's broker object, opened by a click (LibsAddonTools' error display, BugSack...).
local DISPLAYS = { "Libs Error Display", "BugSack" }

-- The Lua errors of this session as the error addon caught them (BugGrabber, which keeps them, any addon's), nil
-- without one; the last of them.
local function luaErrors()
    local grabber = _G.BugGrabber
    if type(grabber) ~= "table" or type(grabber.GetDB) ~= "function" then
        return nil
    end
    local db = ns.Call(grabber.GetDB, grabber)
    local session = ns.Call(grabber.GetSessionId, grabber)
    if type(db) ~= "table" then
        return nil
    end
    local n, last = 0, nil
    for _, e in ipairs(db) do
        if type(e) == "table" and (session == nil or e.session == session) then
            n = n + (tonumber(e.counter) or 1)
            last = e
        end
    end
    return n, last
end

local function display()
    local ldb = Hub.Broker()
    for _, name in ipairs(DISPLAYS) do
        local o = ldb and ns.Call(ldb.GetDataObjectByName, ldb, name)
        if type(o) == "table" and type(o.OnClick) == "function" then
            return o
        end
    end
end

Hub.Add(ERRORS, {
    type = "data source", text = "", atlas = "uitools-icon-warning", category = "system", home = "session",
    label = ns.G("ERRORS", "Errors"),
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("ERRORS", "Errors"))
        local n, last = luaErrors()
        if n then
            Infos.Line(tooltip, L.ERRORS_LUA, tostring(n))
            if last and type(last.message) == "string" then
                Infos.Hint(tooltip, (last.message:match("[^\n]+") or last.message))
            end
        else
            Infos.Text(tooltip, L.ERRORS_NO_ADDON)
        end
        Infos.Line(tooltip, L.ERRORS_BLOCKED, tostring(blockedCount))
        for i = math.max(1, #blocked - 4), #blocked do
            local b = blocked[i]
            Infos.Hint(tooltip, string.format("%s : %s", tostring(b.addon), tostring(b.what)))
        end
        Infos.Hint(tooltip, display() and L.HINT_ERRORS or L.HINT_ERRORS_REPORT)
    end,
    OnClick = function(self, button)
        if button ~= "LeftButton" then
            return
        end
        local o = display()
        if o then
            ns.SafeCall(o.OnClick, self, button)
        else
            ns.SafeCall(ns.Report and ns.Report.Open)
        end
    end,
}, "hidden", 810)

-- Some errors, their count's colour: one table, as the session's.
local SOME = { 1, 0.3, 0.3 }

local function updateErrors()
    local n = (luaErrors() or 0) + blockedCount
    Hub.Set(ERRORS, "textColor", n > 0 and SOME or nil)
    Hub.Set(ERRORS, "text", tostring(n))
end
Infos.OnStart(function()
    for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
        ns.On(event, function(_, addon, what)
            blockedCount = blockedCount + 1
            blocked[#blocked + 1] = { addon = addon, what = what }
            if #blocked > BLOCKED_KEPT then
                table.remove(blocked, 1)
            end
            ns.Later("infos errors", updateErrors)
        end)
    end
    -- the error addon's own callback, as its display listens (taint-safe: EventRegistry runs it apart)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function()
            ns.Later("infos errors", updateErrors)
        end, Infos)
    end
end)
Infos.Updates(updateErrors, { "PLAYER_ENTERING_WORLD" })

-- The session's folder: its time, its errors, then the game's commands, each macro's seed its key among those made
-- for the folder (UI/Hub/Seeds.lua).
local function command(name, fallback)
    return ns.G(name, fallback)
end
ns.Seeds.Contents.session = { SESSION, ERRORS, SEP,
    { seed = "reload", name = ns.G("RELOADUI", "Reload"), icon = "uitools-icon-refresh",
        text = command("SLASH_RELOAD1", "/reload") },
    { seed = "cooldowns", name = ns.G("HUD_EDIT_MODE_COOLDOWN_VIEWER_LABEL", "Cooldown Manager"),
        icon = "uitools-icon-settings", text = command("SLASH_COOLDOWNMANAGER1", "/cdm") },
    { seed = "logout", name = ns.G("LOGOUT", "Log Out"), icon = "common-icon-exit",
        text = command("SLASH_LOGOUT1", "/logout") },
    { seed = "quit", name = ns.G("QUIT", "Quit"), icon = "uitools-icon-error-fill", text = command("SLASH_QUIT1", "/quit") },
}

-- ---------- The character's record ----------

local POINTS, DEATHS = "KaLiHUD_Achievements", "KaLiHUD_Deaths"
-- The game's statistics shown, by id (its achievement table's): total deaths first, then these, each named by the
-- game; one this build doesn't know shows nowhere.
local TOTAL_DEATHS = 60
local STATISTICS = { 1197, 98, 328, 334, 349, 353, 588, 319, 320 }
local deaths = 0

-- A statistic's name and value as the game gives them (its value a text, "--" for none).
local function statistic(id)
    local _, name = ns.Call(GetAchievementInfo, id)
    if type(name) ~= "string" then
        return nil
    end
    local value = ns.Call(GetStatistic, id)
    return name, type(value) == "string" and value or tostring(value or "--")
end

local openStatistics = Infos.Opener(function()
    ToggleAchievementFrame(true)
end)

Hub.Add(POINTS, {
    type = "data source", text = "", atlas = "UI-Achievement-Shield-1", category = "character", home = "statistics",
    label = ns.G("ACHIEVEMENT_POINTS", "Achievement Points"),
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("ACHIEVEMENT_POINTS", "Achievement Points"))
        Infos.Text(tooltip, Format.Number(ns.Call(GetTotalAchievementPoints) or 0))
        Infos.Hint(tooltip, L.HINT_ACHIEVEMENTS)
    end,
    OnClick = Infos.Opener(function()
        ToggleAchievementFrame()
    end),
}, "hidden", 900)

Hub.Add(DEATHS, {
    type = "data source", text = "", atlas = "Navigation-Tombstone-Icon", category = "character", home = "statistics",
    label = ns.G("DEATHS", "Deaths"),
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("DEATHS", "Deaths"))
        Infos.Line(tooltip, L.DEATHS_SESSION, tostring(deaths))
        ns.Items.MeasureLine(tooltip)
        local name, total = statistic(TOTAL_DEATHS)
        if name then
            Infos.Line(tooltip, name, total)
        end
        Infos.Hint(tooltip, L.HINT_STATISTICS)
    end,
    OnClick = openStatistics,
}, "hidden", 910)

local statistics = { POINTS, DEATHS, SEP }
for i, id in ipairs(STATISTICS) do
    local item = "KaLiHUD_Statistic_" .. id
    statistics[#statistics + 1] = item
    Hub.Add(item, {
        type = "data source", text = "", category = "character", home = "statistics",
        available = function()
            return statistic(id) ~= nil
        end,
        OnTooltipShow = function(tooltip)
            local name, value = statistic(id)
            Infos.Title(tooltip, name)
            Infos.Text(tooltip, value)
            Infos.Hint(tooltip, L.HINT_STATISTICS)
        end,
        OnClick = openStatistics,
    }, "hidden", 920 + i)
end
ns.Seeds.Contents.statistics = statistics

local function updateRecord()
    Hub.Set(POINTS, "text", Format.Number(ns.Call(GetTotalAchievementPoints) or 0))
    Hub.Set(DEATHS, "text", tostring(deaths))
    for _, id in ipairs(STATISTICS) do
        local name, value = statistic(id)
        if name then
            Hub.Set("KaLiHUD_Statistic_" .. id, "label", name)
            Hub.Set("KaLiHUD_Statistic_" .. id, "text", name .. " " .. value)
        end
    end
end
Infos.OnStart(function()
    ns.On("PLAYER_DEAD", function()
        deaths = deaths + 1
        ns.Later("infos deaths", updateRecord)
    end)
end)

-- A new measure (UI/Hub/Items.lua; the session readout's menu): the deaths counted and the session's time shown start
-- again with the gold's and the experience's figures.
function Infos.NewMeasure()
    deaths = 0
    ns.Items.NewMeasure()
    updateSession()
    updateRecord()
end
Infos.Updates(updateRecord, { "PLAYER_ENTERING_WORLD", "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE" })

-- For the tests.
ns.Session = { Blocked = blocked, LuaErrors = luaErrors, Statistic = statistic }
