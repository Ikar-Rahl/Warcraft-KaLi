-- The place and the time (Ikar 2026-11-16: "zone pvp status (with different color icon for type)", "fishing, the
-- zone level", "alarm, stopwatch, countdown", "calendar (today event)"): the zone's PvP state as the minimap words and
-- colours it, its level range as the game gives it, today's events of the calendar and its invitations, the clock's
-- alarm, and the game's own stopwatch, a countdown started from its menu. The windows are the game's.
local _, ns = ...

local Infos, Hub, L = ns.Infos, ns.Hub, ns.L

-- ---------- The zone's PvP state ----------

local PVP = "KaLiHUD_ZonePvP"
-- Each state's colour, the minimap's own (Blizzard_Minimap's Minimap_Update), and its words, the game's (in brackets
-- there, without them here).
local STATES = {
    sanctuary = { 0.41, 0.8, 0.94, "SANCTUARY_TERRITORY" },
    arena = { 1, 0.1, 0.1, "FREE_FOR_ALL_TERRITORY" },
    friendly = { 0.1, 1, 0.1, "FACTION_CONTROLLED_TERRITORY" },
    hostile = { 1, 0.1, 0.1, "FACTION_CONTROLLED_TERRITORY" },
    contested = { 1, 0.7, 0, "CONTESTED_TERRITORY" },
    combat = { 1, 0.1, 0.1, "COMBAT_ZONE" },
}
local NEUTRAL = { NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.r or 1, NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.g or 0.82,
    NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.b or 0 }

local function unbracket(text)
    return (tostring(text or ""):gsub("^%s*%((.*)%)%s*$", "%1"))
end

-- Whose a friendly or hostile zone is where the game names no faction (a PvE realm's, its own zone text then giving the
-- colour alone; Ikar 2026-11-21: "Aucun status jcj ... why ?"): a friendly one the player's faction's, a hostile one
-- the other's, in the game's words.
local function factionOf(kind)
    local english, own = ns.Plain(ns.Call(UnitFactionGroup, "player"))
    if kind == "friendly" then
        return own
    end
    return english == "Alliance" and _G.FACTION_HORDE or english == "Horde" and _G.FACTION_ALLIANCE or nil
end

-- The state's words and colour; nil words where the zone has none.
local function pvpState()
    local kind, _, faction = ns.Call(C_PvP.GetZonePVPInfo)
    local state = STATES[kind]
    if not state then
        return nil, NEUTRAL
    end
    local words = _G[state[4]]
    if type(words) ~= "string" then
        return kind, state
    end
    if state[4] == "FACTION_CONTROLLED_TERRITORY" then
        if not (type(faction) == "string" and faction ~= "") then
            faction = factionOf(kind)
        end
        if not (type(faction) == "string" and faction ~= "") then
            return nil, state
        end
        words = string.format(words, faction)
    end
    return unbracket(words), state
end

Hub.Add(PVP, {
    type = "data source", text = "", atlas = "CrossedFlags", iconGrey = true, category = "world", home = "infos",
    label = L.ITEM_ZONE_PVP,
    OnTooltipShow = function(tooltip)
        local words, c = pvpState()
        Infos.Title(tooltip, GetZoneText() or "")
        tooltip:AddLine(words or L.PVP_NONE, c[1], c[2], c[3], true)
        Infos.Hint(tooltip, L.HINT_MAP)
    end,
    OnClick = Infos.Opener(function()
        ns.Items.ToggleMap()
    end),
}, "hidden", 500)

local function updatePvp()
    local words, c = pvpState()
    Hub.Set(PVP, "iconR", c[1])
    Hub.Set(PVP, "iconG", c[2])
    Hub.Set(PVP, "iconB", c[3])
    Hub.Set(PVP, "textColor", c)
    Hub.Set(PVP, "text", words or L.PVP_NONE)
end
Infos.Updates(updatePvp, { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "UPDATE_FACTION" })

-- ---------- The zone's level ----------

local LEVEL = "KaLiHUD_ZoneLevel"

local function levelColor(level)
    local c = type(GetCreatureDifficultyColor) == "function" and GetCreatureDifficultyColor(level)
    return c and { c.r, c.g, c.b } or { 1, 1, 1 }
end

Hub.Add(LEVEL, {
    type = "data source", text = "", category = "world", home = "infos", label = L.ITEM_ZONE_LEVEL,
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("LEVEL_RANGE", "Levels"))
        local low, high = ns.Skills.ZoneLevels()
        Infos.Line(tooltip, GetZoneText() or "", low and (low == high and tostring(low) or low .. "-" .. high) or L.ZONE_NO_LEVEL)
        Infos.Hint(tooltip, L.ZONE_LEVEL_TIP)
    end,
    OnClick = Infos.Opener(function()
        ns.Items.ToggleMap()
    end),
}, "hidden", 510)

local function updateLevel()
    local low, high = ns.Skills.ZoneLevels()
    local text = low and (low == high and tostring(low) or low .. "-" .. high) or "—"
    Hub.Set(LEVEL, "textColor", low and levelColor(math.floor((low + high) / 2)) or nil)
    Hub.Set(LEVEL, "text", ns.G("LEVEL_ABBR", "Lvl") .. " " .. text)
end
Infos.Updates(updateLevel, { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP" })

-- ---------- Today's calendar ----------

local CALENDAR = "KaLiHUD_Today"

-- Today's events from the calendar's data, whatever month its window shows: { title, all day, hour, minute }.
local function today()
    local now = ns.Call(C_DateAndTime.GetCurrentCalendarTime)
    local shown = ns.Call(C_Calendar.GetMonthInfo, 0)
    local list = {}
    if type(now) ~= "table" or type(shown) ~= "table" or not shown.month then
        return list
    end
    local offset = (now.year - shown.year) * 12 + now.month - shown.month
    local n = ns.Plain(ns.Call(C_Calendar.GetNumDayEvents, offset, now.monthDay)) or 0
    for i = 1, n do
        local e = ns.Plain(ns.Call(C_Calendar.GetDayEvent, offset, now.monthDay, i))
        if type(e) == "table" and type(e.title) == "string" then
            local start = type(e.startTime) == "table" and e.startTime or {}
            list[#list + 1] = { title = e.title, holiday = e.calendarType == "HOLIDAY", hour = start.hour,
                minute = start.minute }
        end
    end
    return list
end

local function invites()
    return ns.Call(C_Calendar.GetNumPendingInvites) or 0
end

Hub.Add(CALENDAR, {
    type = "data source", text = "", atlas = "ui-hud-minimap-calendar-button", category = "time", home = "infos",
    label = L.CALENDAR_TODAY,
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, L.CALENDAR_TODAY)
        local list = today()
        for _, e in ipairs(list) do
            local when = (e.holiday or not e.hour) and "" or string.format("%02d:%02d", e.hour, e.minute or 0)
            Infos.Line(tooltip, e.title, when)
        end
        if #list == 0 then
            Infos.Text(tooltip, L.CALENDAR_NONE)
        end
        local n = invites()
        if n > 0 then
            Infos.Line(tooltip, L.CALENDAR_INVITES, tostring(n))
        end
        Infos.Hint(tooltip, L.HINT_CALENDAR)
    end,
    OnClick = Infos.Opener(function()
        ToggleCalendar()
    end),
}, "hidden", 520)

local function updateCalendar()
    local n = invites()
    Hub.Set(CALENDAR, "text", tostring(#today()) .. (n > 0 and Infos.Color(" +" .. n, "ffffd200") or ""))
end
-- The month's events asked of the server once, as the calendar's own button does when it loads: nothing shows.
Infos.OnStart(function()
    ns.Call(C_Calendar.OpenCalendar)
end)
Infos.Updates(updateCalendar, { "PLAYER_ENTERING_WORLD", "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_UPDATE_PENDING_INVITES" },
    60)

-- ---------- The alarm, the stopwatch ----------

local ALARM, STOPWATCH = "KaLiHUD_Alarm", "KaLiHUD_Stopwatch"

local function timeManager()
    if not _G.TimeManager_Toggle then
        ns.Call(C_AddOns.LoadAddOn, "Blizzard_TimeManager")
    end
end

-- The alarm the clock's window sets: on or off, and when (minutes past midnight, its CVar).
local function alarm()
    local on = GetCVar("timeMgrAlarmEnabled") == "1"
    local minutes = tonumber(GetCVar("timeMgrAlarmTime") or "") or 0
    return on, string.format("%02d:%02d", math.floor(minutes / 60) % 24, minutes % 60)
end

Hub.Add(ALARM, {
    type = "data source", text = "", atlas = "icon-clock", category = "time", home = "infos", label = L.ITEM_ALARM,
    OnTooltipShow = function(tooltip)
        -- the clock window's own words: « Alarme activée » or « désactivée », then when
        local on, at = alarm()
        Infos.Title(tooltip, on and ns.G("TIMEMANAGER_ALARM_ENABLED", "Alarm Enabled")
            or ns.G("TIMEMANAGER_ALARM_DISABLED", "Alarm Disabled"))
        Infos.Line(tooltip, ns.G("TIMEMANAGER_ALARM_TIME", "Alarm Time"), at)
        local message = GetCVar("timeMgrAlarmMessage")
        if on and type(message) == "string" and message ~= "" then
            Infos.Text(tooltip, message)
        end
        Infos.Hint(tooltip, L.HINT_ALARM)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" then
            timeManager()
            ns.Call(_G.TimeManager_Toggle)
        end
    end,
}, "hidden", 530)

local function updateAlarm()
    local on, at = alarm()
    Hub.Set(ALARM, "text", on and at or ns.G("OFF", "Off"))
end
Infos.Updates(updateAlarm, { "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" })

-- A countdown of `minutes` on the game's stopwatch, started (its play button its own after).
local function countdown(minutes)
    timeManager()
    if type(_G.Stopwatch_StartCountdown) == "function" then
        ns.SafeCall(_G.Stopwatch_StartCountdown, 0, minutes, 0)
        ns.Call(_G.Stopwatch_Play)
    end
end

local COUNTDOWNS = { 1, 3, 5, 10, 15, 30, 60 }
local countdownEntries = {}
for _, m in ipairs(COUNTDOWNS) do
    countdownEntries[#countdownEntries + 1] = { text = string.format(L.COUNTDOWN_MINUTES, m), func = function()
        countdown(m)
    end }
end

Hub.Add(STOPWATCH, {
    type = "launcher", label = ns.G("STOPWATCH_TITLE", "Stopwatch"), atlas = "ChromieTime-32x32", category = "time",
    home = "infos",
    OnTooltipShow = function(tooltip)
        Infos.Title(tooltip, ns.G("STOPWATCH_TITLE", "Stopwatch"))
        Infos.Hint(tooltip, L.HINT_STOPWATCH)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" then
            timeManager()
            ns.Call(_G.Stopwatch_Toggle)
        end
    end,
    menu = { { text = ns.G("COUNTDOWN", "Countdown"), items = countdownEntries } },
}, "hidden", 540)

-- For the tests.
ns.World = { Countdown = countdown, PvpState = pvpState, Today = today }
