-- What the addon takes from the game, looked for in this client: the list in Data/Needs.lua, made from the code
-- offline, and what it assumes of the game's answers, tried on the player's quest log. Run at login, kept per build
-- in KaLiQuestDevDB.apiChecks, and again for each bug report. It changes nothing, but says once in chat when something
-- isn't as assumed. Also keeps what the game reports against the addon: a blocked action, a Lua warning in its files.
local ADDON, ns = ...

local SelfCheck = {}
ns.SelfCheck = SelfCheck

local BUILDS_KEPT = 5
local WARNINGS_KEPT = 20
local last

local function resolve(name)
    local value = _G
    for part in name:gmatch("[^.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

-- A name one of Blizzard's addons defines is only missing once one of them has loaded.
local function anyLoaded(addons)
    if addons == "" then
        return true
    end
    for addon in addons:gmatch("[^,]+") do
        if ns.Call(C_AddOns.IsAddOnLoaded, addon) then
            return true
        end
    end
    return false
end

-- What the addon assumes of the quest log, tried on the player's own: each header's headerSortKey holds an area or
-- a QuestSort ID that names it, the class header its class's, and the key places it as its name does where both can
-- tell. Returns how many headers it looked at and what didn't hold. See Categories.
function SelfCheck.Headers()
    local looked, wrong = 0, {}
    local names = ns.SORT_NAMES[ns.LOCALE]
    local _, classFile = UnitClass("player")
    local ownName = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
    local classSort = ns.Categories.CLASS_SORT[classFile]
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            looked = looked + 1
            local title, key = info.title, info.headerSortKey
            local what, id = ns.Categories.DecodeKey(key)
            local problem
            if not what then
                problem = string.format("key %s is neither an area nor a QuestSort", tostring(key))
            elseif what == "area" then
                local name = ns.Call(C_Map.GetAreaInfo, id)
                if name ~= title then
                    problem = string.format("area %d is named %s", id, tostring(name))
                end
            elseif not ns.SORT_KIND[id] then
                problem = string.format("QuestSort %d isn't in the addon's data", id)
            elseif names and names[id] ~= title then
                problem = string.format("QuestSort %d is named %s", id, tostring(names[id]))
            elseif title == ownName and id ~= classSort then
                problem = string.format("QuestSort %d, but %s's is %s", id, tostring(classFile), tostring(classSort))
            end
            if not problem and names and ns.categories then
                local keyCategory, keyKind = ns.categories.Classify(title, key)
                local nameCategory, nameKind = ns.categories.Classify(title)
                if keyCategory ~= nameCategory or keyKind ~= nameKind then
                    problem = string.format("its key puts it in %s/%s, its name in %s/%s", keyCategory, keyKind, nameCategory,
                        nameKind)
                end
            end
            if problem then
                wrong[#wrong + 1] = string.format("header %q: %s", tostring(title), problem)
            end
        end
    end
    return looked, wrong
end

-- Every quest shows in the log's rows, even under a header collapsed in the game's own log, as QuestLog reads only
-- those rows. Hidden quests count as rows too, so whether the game counts them makes no false alarm.
function SelfCheck.Listing()
    local entries, quests = C_QuestLog.GetNumQuestLogEntries()
    local rows, collapsed = 0, 0
    for i = 1, entries do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            collapsed = collapsed + (info.isCollapsed and 1 or 0)
        elseif info then
            rows = rows + 1
        end
    end
    local wrong = {}
    if rows < quests then
        wrong[1] = string.format("%d quests listed of %d", rows, quests)
    end
    return quests, wrong, collapsed .. " headers collapsed in the game's log"
end

-- The game's own numbers the addon reads, against the game's enums and constants for them.
function SelfCheck.Numbers()
    local F = ns.Filter
    local list = {
        { "Constants.QuestInfoLuaConsts.QUEST_INFO_ELITE_ID", F.TAG.elite },
        { "Constants.QuestInfoLuaConsts.QUEST_INFO_PVP_ID", F.TAG.pvp },
        { "Constants.QuestInfoLuaConsts.QUEST_INFO_RAID_ID", F.TAG.raid },
        { "Constants.QuestInfoLuaConsts.QUEST_INFO_DUNGEON_ID", F.TAG.dungeon },
        { "Enum.QuestTag.Legendary", F.TAG.legendary },
        { "Enum.QuestTag.Raid10", F.TAG.raid10 },
        { "Enum.QuestTag.Raid25", F.TAG.raid25 },
        { "Enum.QuestClassification.Questline", F.QUESTLINE },
        { "Constants.QuestWatchConsts.MAX_QUEST_WATCHES", ns.Model.WATCH_LIMIT },
    }
    for name, value in pairs(F.FREQUENCY) do
        list[#list + 1] = { "Enum.QuestFrequency." .. name, value }
    end
    for i, name in ipairs(F.DIFFICULTY) do
        list[#list + 1] = { "Enum.RelativeContentDifficulty." .. name, i - 1 }
    end
    for i, name in ipairs(F.CLASSIFICATION) do
        list[#list + 1] = { "Enum.QuestClassification." .. name, i - 1 }
    end
    local wrong = {}
    for _, pair in ipairs(list) do
        local game = resolve(pair[1])
        if game ~= pair[2] then
            wrong[#wrong + 1] = string.format("%s is %s, the addon reads %s", pair[1], tostring(game), tostring(pair[2]))
        end
    end
    table.sort(wrong)
    return #list, wrong
end

-- GetZoneText() is the name of the area your map shows, as that zone's log header is: Monde puts the header first,
-- and the filter's "Zone actuelle" finds it, by that text. Each zone is tried once a session.
local zones = { looked = 0, seen = {}, wrong = {} }
local function noteZone()
    local area = ns.MAP_AREAS[ns.Call(C_Map.GetBestMapForUnit, "player") or 0]
    local zone = GetZoneText()
    if not area or zones.seen[area] or zone == nil or zone == "" then
        return
    end
    zones.seen[area] = true
    zones.looked = zones.looked + 1
    local name = ns.Call(C_Map.GetAreaInfo, area)
    if name ~= zone then
        zones.wrong[#zones.wrong + 1] = string.format("area %d is named %s, GetZoneText() says %s", area, tostring(name),
            tostring(zone))
    end
end

-- An addon may set auto-tracking, and Shift is the game's key for tracking and for links, as the tips and hints say.
function SelfCheck.Settings()
    local wrong = {}
    local value, _, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo("autoQuestWatch")
    if value == nil or locked or secure or readOnly then
        wrong[#wrong + 1] = string.format("autoQuestWatch: value %s, locked %s, secure %s, read-only %s", tostring(value),
            tostring(locked), tostring(secure), tostring(readOnly))
    end
    for _, action in ipairs({ "QUESTWATCHTOGGLE", "CHATLINK" }) do
        local key = GetModifiedClick(action)
        if key ~= "SHIFT" then
            wrong[#wrong + 1] = string.format("%s is %s, not SHIFT", action, tostring(key))
        end
    end
    return 3, wrong
end

-- Blizzard's tracker and its sections, and the addon's own frames, aren't protected: they're parked, moved and
-- changed in a fight.
function SelfCheck.Frames()
    local looked, wrong = 0, {}
    local function free(name, f)
        if type(f) == "table" and f.IsProtected then
            looked = looked + 1
            if f:IsProtected() then
                wrong[#wrong + 1] = name .. " is protected"
            end
        end
    end
    free("ObjectiveTrackerFrame", ObjectiveTrackerFrame)
    for _, group in ipairs({ ns.Coverage.DRAWN, ns.Coverage.SECTIONS }) do
        for _, s in ipairs(group) do
            free(s.frame, _G[s.frame])
        end
    end
    free("KaLiQuestTracker", KaLiQuestTracker)
    return looked, wrong
end

-- Each refusal of AddQuestWatch this session, which the model reads as the game's limit reached.
local refusals = { looked = 0, wrong = {} }

local ASSUMPTIONS = {
    { "log headers", SelfCheck.Headers },
    { "log listing", SelfCheck.Listing },
    { "game numbers", SelfCheck.Numbers },
    { "zone name", function()
        noteZone()
        return zones.looked, zones.wrong
    end },
    { "settings", SelfCheck.Settings },
    { "frames", SelfCheck.Frames },
    { "tracking limit", function()
        return refusals.looked, refusals.wrong
    end },
}

-- Each assumption as it stands: { name, looked, wrong, note }, and how many things don't hold in all.
function SelfCheck.Assumptions()
    local out, failing = {}, 0
    for _, a in ipairs(ASSUMPTIONS) do
        local ok, looked, wrong, note = pcall(a[2])
        if not ok then
            wrong, looked, note = { "the check failed: " .. tostring(looked) }, 0, nil
        end
        out[#out + 1] = { name = a[1], looked = looked, wrong = wrong, note = note }
        failing = failing + #wrong
    end
    return out, failing
end

-- { checked, skipped, missing = { "kind name", sorted }, assumed, failing } for this client now.
function SelfCheck.Run()
    local needs = ns.NEEDS or {}
    local result = { checked = 0, skipped = 0, missing = {} }
    local function check(kind, name, present)
        result.checked = result.checked + 1
        if not present then
            result.missing[#result.missing + 1] = kind .. " " .. name
        end
    end
    for name, addons in pairs(needs.globals or {}) do
        if resolve(name) ~= nil then
            check("global", name, true)
        elseif anyLoaded(addons) then
            check("global", name, false)
        else
            result.skipped = result.skipped + 1
        end
    end
    local templateInfo = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    for name, addons in pairs(needs.templates or {}) do
        if templateInfo and anyLoaded(addons) then
            check("template", name, ns.Call(templateInfo, name) ~= nil)
        else
            result.skipped = result.skipped + 1
        end
    end
    local tests = {
        { "event", needs.events, C_EventUtils and C_EventUtils.IsEventValid, true },
        { "atlas", needs.atlases, C_Texture and C_Texture.GetAtlasInfo },
        { "cvar", needs.cvars, C_CVar and C_CVar.GetCVarInfo },
    }
    for _, t in ipairs(tests) do
        local kind, list, fn, isFlag = t[1], t[2] or {}, t[3], t[4]
        for _, name in ipairs(list) do
            if fn then
                local answer = ns.Call(fn, name)
                check(kind, name, isFlag and answer == true or not isFlag and answer ~= nil)
            else
                result.skipped = result.skipped + 1
            end
        end
    end
    for _, name in ipairs(needs.strings or {}) do
        check("string", name, type(_G[name]) == "string")
    end
    table.sort(result.missing)
    result.assumed, result.failing = SelfCheck.Assumptions()
    last = result
    return result
end

function SelfCheck.Last()
    return last
end

local current -- this build's entry in KaLiQuestDevDB.apiChecks, from login

-- Once per build and addon version. A missing game string isn't worth it: the addon has its own wording for each.
local function tell()
    local count = current.failing or 0
    for _, m in ipairs(current.missing or {}) do
        if not m:find("^string ") then
            count = count + 1
        end
    end
    if count > 0 and not current.told then
        current.told = true
        ns.Say(ns.L.API_NOT_AS_ASSUMED)
    end
end

-- Brings this build's entry, and the diagnostics' copy, up to date with the assumptions as they stand.
local function store()
    if not current then
        return
    end
    current.assumed, current.failing = SelfCheck.Assumptions()
    if last then
        last.assumed, last.failing = current.assumed, current.failing
    end
    tell()
end

-- The log is usually still empty at login, and the tracker and the zone not there yet, so all is tried again once
-- the log has something in it.
local function later()
    if (C_QuestLog.GetNumQuestLogEntries() or 0) == 0 then
        return
    end
    ns.Off("QUEST_LOG_UPDATE", later)
    store()
end

function SelfCheck.NoteRefusal(questID, tracked)
    refusals.looked = refusals.looked + 1
    if (tracked or 0) < ns.Model.WATCH_LIMIT and #refusals.wrong < 10 then
        refusals.wrong[#refusals.wrong + 1] = string.format("AddQuestWatch(%d) refused with %s tracked", questID,
            tostring(tracked))
    end
    store()
end

ns.On("ZONE_CHANGED_NEW_AREA", function()
    noteZone()
    store()
end)

-- At login: this build's result, replacing an older one for the same build and version but not whether it was said,
-- a few builds kept.
function SelfCheck.AtLogin()
    local result = SelfCheck.Run()
    local d = KaLiQuestDevDB
    if type(d) ~= "table" then
        return
    end
    local _, build = GetBuildInfo()
    local list = type(d.apiChecks) == "table" and d.apiChecks or {}
    local told
    for i = #list, 1, -1 do
        if type(list[i]) ~= "table" or list[i].build == build and list[i].version == ns.VERSION then
            told = told or type(list[i]) == "table" and list[i].told or nil
            table.remove(list, i)
        end
    end
    current = { build = build, version = ns.VERSION, when = date("%Y-%m-%d %H:%M"), checked = result.checked,
        missing = result.missing, assumed = result.assumed, failing = result.failing, told = told }
    list[#list + 1] = current
    while #list > BUILDS_KEPT do
        table.remove(list, 1)
    end
    d.apiChecks = list
    ns.On("QUEST_LOG_UPDATE", later)
end
ns.On("PLAYER_LOGIN", SelfCheck.AtLogin)

-- A report like the last one adds to its count.
local function note(kind, text)
    local d = KaLiQuestDevDB
    if type(d) ~= "table" then
        return
    end
    local list = type(d.gameWarnings) == "table" and d.gameWarnings or {}
    d.gameWarnings = list
    local now = date("%Y-%m-%d %H:%M:%S")
    local prev = list[#list]
    if type(prev) == "table" and prev.kind == kind and prev.text == text then
        prev.count, prev.when = (prev.count or 1) + 1, now
        return
    end
    list[#list + 1] = { when = now, kind = kind, text = tostring(text), count = 1 }
    while #list > WARNINGS_KEPT do
        table.remove(list, 1)
    end
end

function SelfCheck.WarningsText()
    local lines = {}
    local list = KaLiQuestDevDB and KaLiQuestDevDB.gameWarnings
    for _, w in ipairs(type(list) == "table" and list or {}) do
        lines[#lines + 1] = string.format("%s  %s  x%d  %s", tostring(w.when), tostring(w.kind), w.count or 1, tostring(w.text))
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end

-- The game names the addon it blames, and a warning names the file.
ns.On("ADDON_ACTION_BLOCKED", function(_, addon, fn)
    if addon == ADDON then
        note("blocked", fn)
    end
end)
ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, fn)
    if addon == ADDON then
        note("forbidden", fn)
    end
end)
ns.On("LUA_WARNING", function(_, ...)
    local n = select("#", ...)
    local text = n > 0 and select(n, ...) or nil
    if type(text) == "string" and text:find("AddOns[\\/]" .. ADDON .. "[\\/]") then
        note("warning", text)
    end
end)
