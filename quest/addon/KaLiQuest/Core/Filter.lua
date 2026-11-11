-- Filter and search, from docs/filter-search.md. Neither moves a quest or touches what's open: they only hide rows.
-- Within one filter category a quest needs any ticked value; across categories it needs all of them.
local _, ns = ...
local L = ns.L

local Filter = {}
ns.Filter = Filter

-- Colour codes, textures and links reduced to their text, then accents and case folded.
local function plain(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return ns.Fold(s)
end
Filter.Plain = plain

-- Every word of the query, anywhere in the text, in any order. Plain find, so ( or % can't break it.
function Filter.Matches(text, query)
    local any = false
    for word in plain(query):gmatch("[^ \t]+") do
        any = true
        if not text:find(word, 1, true) then
            return false
        end
    end
    return any
end

function Filter.Searching(query)
    return type(query) == "string" and query:find("[^ \t]") ~= nil
end

function Filter.Active(filters)
    for _, set in pairs(filters or {}) do
        if next(set) then
            return true
        end
    end
    return false
end

-- traits: { [categoryID] = { valueID = true } }. filters: the saved ticks, the same shape.
function Filter.Passes(traits, filters)
    for cat, ticked in pairs(filters or {}) do
        if next(ticked) then
            local has = traits[cat] or {}
            local ok = false
            for value in pairs(ticked) do
                if has[value] then
                    ok = true
                    break
                end
            end
            if not ok then
                return false
            end
        end
    end
    return true
end

-- Menu order. A label is a string or a function of the value's suffix.
local DIFFICULTY = { "Trivial", "Easy", "Fair", "Difficult", "Impossible" }
local CLASSIFICATION = { "Important", "Legendary", "Campaign", "Calling", "Meta", "Recurring" }

-- The game's own numbers the filter reads. The two lists above are in the game's order, from 0. In game the API
-- check holds each against the game's enums, and offline run_lua_tests.py holds the tags against its QuestInfo table.
Filter.DIFFICULTY, Filter.CLASSIFICATION, Filter.QUESTLINE = DIFFICULTY, CLASSIFICATION, 6
Filter.TAG = { elite = 1, life = 21, pvp = 41, raid = 62, dungeon = 81, worldevent = 82, legendary = 83, raid10 = 88, raid25 = 89 }
Filter.FREQUENCY = { Default = 0, Daily = 1, Weekly = 2, ResetByScheduler = 3 }
local TAG, FREQUENCY = Filter.TAG, Filter.FREQUENCY
Filter.CATEGORIES = {
    { id = "type", values = { "elite", "dungeon", "raid", "pvp", "legendary", "worldevent", "tag21" } },
    { id = "size" },
    { id = "repeat", values = { "daily", "weekly", "scheduled", "repeatable", "once" } },
    { id = "state", values = { "progress", "ready", "failed", "timed", "item", "sequenced" } },
    { id = "diff", values = DIFFICULTY },
    { id = "class", values = CLASSIFICATION },
    { id = "story", values = { "story", "questline" } },
    { id = "account", values = { "account", "alliance", "horde" } },
    { id = "party", values = { "member", "shareable", "findgroup" } },
    { id = "place", values = { "onmap", "zone" } },
}

local LABELS = {
    elite = function()
        return ns.G("ELITE", "Élite")
    end,
    dungeon = function()
        return ns.G("CALENDAR_TYPE_DUNGEON", "Donjon")
    end,
    raid = function()
        return ns.G("RAID", "Raid")
    end,
    pvp = function()
        return ns.G("CALENDAR_TYPE_PVP", "JcJ")
    end,
    account = function()
        return ns.G("ACCOUNT_QUEST_LABEL", "Compte")
    end,
    alliance = function()
        return ns.G("FACTION_ALLIANCE", "Alliance")
    end,
    horde = function()
        return ns.G("FACTION_HORDE", "Horde")
    end,
    ready = function()
        return ns.G("QUEST_WATCH_QUEST_READY", "À rendre")
    end,
    failed = function()
        return ns.G("FAILED", "Échec")
    end,
}

function Filter.CategoryLabel(id)
    return L["FILTER_" .. id:upper()]
end

-- names: labels the game gave for values it names itself, such as tag 21's.
function Filter.ValueLabel(value, names)
    if names and names[value] then
        return names[value]
    end
    local size = value:match("^size(%d+)$")
    if size then
        return string.format(L.FILTER_V_SIZE, tonumber(size))
    end
    if LABELS[value] then
        return LABELS[value]()
    end
    return L["FILTER_V_" .. value:upper()]
end

-- Each category's values present in the log, with counts, in menu order. A category with one value or none is
-- left out, unless something in it is ticked, so it can be unticked.
function Filter.MenuEntries(allTraits, filters)
    local out = {}
    for _, cat in ipairs(Filter.CATEGORIES) do
        local counts = {}
        for _, traits in pairs(allTraits) do
            for value in pairs(traits[cat.id] or {}) do
                counts[value] = (counts[value] or 0) + 1
            end
        end
        local ticked = filters[cat.id] or {}
        local values = {}
        local seen = {}
        for _, value in ipairs(cat.values or {}) do
            if counts[value] or ticked[value] then
                values[#values + 1] = value
                seen[value] = true
            end
        end
        local rest = {}
        for value in pairs(counts) do
            if not seen[value] then
                rest[#rest + 1] = value
            end
        end
        for value in pairs(ticked) do
            if not seen[value] and not counts[value] then
                rest[#rest + 1] = value
            end
        end
        table.sort(rest, function(a, b)
            local na, nb = tonumber(a:match("%d+$")), tonumber(b:match("%d+$"))
            if na and nb and na ~= nb then
                return na < nb
            end
            return a < b
        end)
        for _, value in ipairs(rest) do
            values[#values + 1] = value
        end
        if #values >= 2 or next(ticked) then
            local entries = {}
            for _, value in ipairs(values) do
                entries[#entries + 1] = { value = value, count = counts[value] or 0, ticked = ticked[value] == true }
            end
            out[#out + 1] = { id = cat.id, entries = entries }
        end
    end
    return out
end

-- Reading the game ------------------------------------------------------------------------------------------

local call = ns.Call

-- Values given as arguments, so a condition that's nil leaves no hole that would end the list.
local function set(...)
    local s = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v then
            s[v] = true
        end
    end
    return s
end

-- The find-group eye opens Blizzard's group finder, which Forever doesn't load (ExcludeLoadGameType camelot).
function Filter.GroupFinderAvailable()
    return LFGListUtil_FindQuestGroup ~= nil and C_LFGList ~= nil
end

-- Asked of C_LFGList itself: QuestUtil's version caches the answer in a table of Blizzard's, which a call from here
-- would taint for Blizzard's own tracker.
function Filter.CanFindGroup(id)
    return Filter.GroupFinderAvailable() and call(C_LFGList.CanCreateQuestGroup, id) == true
end

-- Quest tags by kind. Raids of 10 and 25 players have tags of their own, which Blizzard shows as raids.
Filter.TAGS = { dungeon = { [TAG.dungeon] = true }, raid = { [TAG.raid] = true, [TAG.raid10] = true, [TAG.raid25] = true },
    pvp = { [TAG.pvp] = true } }

-- A quest's values in every category. ctx: { zone, inParty }. names collects labels the game gives.
function Filter.Traits(q, ctx, names)
    local id = q.id
    local tag = call(C_QuestLog.GetQuestTagInfo, id)
    local tagID = tag and tag.tagID
    if tagID == TAG.life and names then
        names.tag21 = tag.tagName
    end
    local elite = call(C_QuestLog.IsEliteQuest, id) or tagID == TAG.elite
    local t = {}
    t.type = set(
        elite and "elite",
        (Filter.TAGS.dungeon[tagID] or q.headerKind == "instance") and "dungeon",
        Filter.TAGS.raid[tagID] and "raid",
        (Filter.TAGS.pvp[tagID] or q.headerKind == "battleground") and "pvp",
        tagID == TAG.legendary and "legendary",
        tagID == TAG.worldevent and "worldevent",
        tagID == TAG.life and "tag21")
    t.size = set((q.suggestedGroup or 0) > 1 and ("size" .. q.suggestedGroup))
    t["repeat"] = set(
        q.frequency == FREQUENCY.Daily and "daily",
        q.frequency == FREQUENCY.Weekly and "weekly",
        q.frequency == FREQUENCY.ResetByScheduler and "scheduled",
        q.repeatable and "repeatable" or "once")
    t.state = set(
        q.failed and "failed" or (q.complete and "ready" or "progress"),
        call(C_QuestLog.GetTimeAllowed, id) and "timed",
        q.logIndex and call(GetQuestLogSpecialItemInfo, q.logIndex) and "item",
        call(IsQuestSequenced, id) and "sequenced")
    local diff = C_PlayerInfo and call(C_PlayerInfo.GetContentDifficultyQuestForPlayer, id)
    t.diff = set(diff and DIFFICULTY[diff + 1])
    local class = C_QuestInfoSystem and call(C_QuestInfoSystem.GetQuestClassification, id)
    t.class = set(class and CLASSIFICATION[class + 1])
    t.story = set(q.isStory and "story", class == Filter.QUESTLINE and "questline")
    local faction = call(GetQuestFactionGroup, id)
    t.account = set(
        call(C_QuestLog.IsAccountQuest, id) and "account",
        faction ~= nil and faction == LE_QUEST_FACTION_ALLIANCE and "alliance",
        faction ~= nil and faction == LE_QUEST_FACTION_HORDE and "horde")
    t.party = set(
        ctx.inParty and (call(QuestUtils_GetNumPartyMembersOnQuest, id) or 0) > 0 and "member",
        ctx.inParty and call(C_QuestLog.IsPushableQuest, id) and "shareable",
        Filter.CanFindGroup(id) and "findgroup")
    t.place = set(call(C_QuestLog.IsOnMap, id) and "onmap", q.header ~= nil and q.header == ctx.zone and "zone")
    return t
end

-- Text that doesn't change while the quest is in the log, kept until it leaves.
local staticText = {}
local requested = {} -- quests whose rewards were asked for once

local function rewardNames(id)
    local names = {}
    if HaveQuestRewardData and not call(HaveQuestRewardData, id) then
        -- QUEST_DATA_LOAD_RESULT then calls Filter.RewardsLoaded.
        if not requested[id] then
            requested[id] = true
            call(C_QuestLog.RequestLoadQuestByID, id)
        end
        return names, false
    end
    for i = 1, call(GetNumQuestLogRewards, id) or 0 do
        names[#names + 1] = call(GetQuestLogRewardInfo, i, id)
    end
    for i = 1, call(GetNumQuestLogChoices, id, true) or 0 do
        names[#names + 1] = call(GetQuestLogChoiceInfo, i, id)
    end
    if C_QuestInfoSystem then
        local currencies = call(C_QuestInfoSystem.GetQuestRewardCurrencies, id)
        for _, c in ipairs(type(currencies) == "table" and currencies or {}) do
            names[#names + 1] = c.name
        end
        local spells = call(C_QuestInfoSystem.GetQuestRewardSpells, id)
        for _, spellID in ipairs(type(spells) == "table" and spells or {}) do
            local info = call(C_QuestInfoSystem.GetQuestRewardSpellInfo, id, spellID)
            names[#names + 1] = type(info) == "table" and info.name or nil
        end
    end
    return names, true
end

local function staticOf(q)
    local cached = staticText[q.id]
    if cached and cached.complete then
        return cached.text
    end
    local parts = { q.title }
    if q.logIndex then
        local description, objectives = call(GetQuestLogQuestText, q.logIndex)
        parts[#parts + 1] = description
        parts[#parts + 1] = objectives
    end
    local rewards, loaded = rewardNames(q.id)
    for _, name in ipairs(rewards) do
        parts[#parts + 1] = name
    end
    local text = plain(table.concat(parts, " "))
    staticText[q.id] = { text = text, complete = loaded }
    return text
end

-- Drops what's cached for quests no longer in the log, and rewards that load later.
function Filter.Forget(quests)
    for id in pairs(staticText) do
        if not quests[id] then
            staticText[id] = nil
        end
    end
    for id in pairs(requested) do
        if not quests[id] then
            requested[id] = nil
        end
    end
end

function Filter.RewardsLoaded(id)
    staticText[id] = nil
end

-- Everything a search looks at: the static text, then objectives, completion and next step, the header, the
-- group's name, the filter labels the quest has, its level and its ID. lines: the objective lines' text.
function Filter.SearchText(q, groupName, traits, lines, names)
    local strings = {}
    local function add(v)
        if v ~= nil and v ~= "" then
            strings[#strings + 1] = tostring(v)
        end
    end
    add(staticOf(q))
    add(q.header)
    add(groupName)
    add(q.difficultyLevel or q.level)
    add(q.id)
    for _, text in ipairs(lines or {}) do
        add(text)
    end
    if q.logIndex and q.complete then
        add(call(GetQuestLogCompletionText, q.logIndex))
    end
    add(call(C_QuestLog.GetNextWaypointText, q.id))
    for _, values in pairs(traits or {}) do
        for value in pairs(values) do
            add(Filter.ValueLabel(value, names))
        end
    end
    return plain(table.concat(strings, " "))
end
