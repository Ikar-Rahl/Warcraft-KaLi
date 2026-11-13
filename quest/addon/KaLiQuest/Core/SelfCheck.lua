-- KaLi Quest's part of the API check (Shared/SelfCheck.lua): what it assumes of the game's answers, tried on the
-- player's quest log, its zone, its settings and its frames, and told once the log has something in it.
local _, ns = ...

local SelfCheck = ns.SelfCheck

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

-- The game's own numbers the addon reads, against the game's enums and constants for them. The quest tags' constants
-- are where Blizzard's own Forever code reads them, Constants.QuestConsts (Camelot's QuestUtilsOverrides.lua): the
-- API docs name their group QuestInfoLuaConsts, which this client doesn't have (Ikar's API check, build 70862).
function SelfCheck.Numbers()
    local F = ns.Filter
    local list = {
        { "Constants.QuestConsts.QUEST_INFO_ELITE_ID", F.TAG.elite },
        { "Constants.QuestConsts.QUEST_INFO_PVP_ID", F.TAG.pvp },
        { "Constants.QuestConsts.QUEST_INFO_RAID_ID", F.TAG.raid },
        { "Constants.QuestConsts.QUEST_INFO_DUNGEON_ID", F.TAG.dungeon },
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
        local game = SelfCheck.Resolve(pair[1])
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
-- The game writes a click's key with its button or without ("SHIFT-BUTTON1" for links, "SHIFT" for tracking,
-- Forever's defaults in Bindings_Camelot.xml), so the button is left out: the key is what the tips name.
function SelfCheck.Settings()
    local wrong = {}
    local value, _, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo("autoQuestWatch")
    if value == nil or locked or secure or readOnly then
        wrong[#wrong + 1] = string.format("autoQuestWatch: value %s, locked %s, secure %s, read-only %s", tostring(value),
            tostring(locked), tostring(secure), tostring(readOnly))
    end
    for _, action in ipairs({ "QUESTWATCHTOGGLE", "CHATLINK" }) do
        local key = GetModifiedClick(action)
        if type(key) ~= "string" or key:gsub("%-?BUTTON%d+", "") ~= "SHIFT" then
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

SelfCheck.Add("log headers", SelfCheck.Headers)
SelfCheck.Add("log listing", SelfCheck.Listing)
SelfCheck.Add("game numbers", SelfCheck.Numbers)
SelfCheck.Add("zone name", function()
    noteZone()
    return zones.looked, zones.wrong
end)
SelfCheck.Add("settings", SelfCheck.Settings)
SelfCheck.Add("frames", SelfCheck.Frames)
SelfCheck.Add("tracking limit", function()
    return refusals.looked, refusals.wrong
end)

-- The log is usually still empty at login, and the tracker and the zone not there yet, so all is tried again, and
-- told, once the log has something in it.
local function later()
    if (C_QuestLog.GetNumQuestLogEntries() or 0) == 0 then
        return
    end
    ns.Off("QUEST_LOG_UPDATE", later)
    SelfCheck.Store()
end

function SelfCheck.AfterLogin()
    ns.On("QUEST_LOG_UPDATE", later)
end

function SelfCheck.NoteRefusal(questID, tracked)
    refusals.looked = refusals.looked + 1
    if (tracked or 0) < ns.Model.WATCH_LIMIT and #refusals.wrong < 10 then
        refusals.wrong[#refusals.wrong + 1] = string.format("AddQuestWatch(%d) refused with %s tracked", questID,
            tostring(tracked))
    end
    SelfCheck.Store()
end

ns.On("ZONE_CHANGED_NEW_AREA", function()
    noteZone()
    SelfCheck.Store()
end)

ns.On("PLAYER_LOGIN", SelfCheck.AtLogin)
