-- What the addon takes from the game, looked for in this client: the list in Data/Needs.lua, made from the code
-- offline, and what it assumes of the game's answers, tried on the player's quest log. Run at login, kept per build
-- in KaLiQuestDevDB.apiChecks, and again for each bug report; it changes nothing. Also keeps what the game reports
-- against the addon: an action it blocked, a Lua warning in its files.
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

local function headers()
    local ok, looked, wrong = pcall(SelfCheck.Headers)
    if ok then
        return looked, wrong
    end
    return 0, { "the check failed: " .. tostring(looked) }
end

-- { checked, skipped, missing = { "kind name", sorted }, headers, wrong } for this client now.
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
    table.sort(result.missing)
    result.headers, result.wrong = headers()
    last = result
    return result
end

function SelfCheck.Last()
    return last
end

-- The log is usually still empty at login, so its headers are tried once it has some, into this build's entry.
local function headersLater()
    local looked, wrong = headers()
    if looked == 0 and #wrong == 0 then
        return
    end
    ns.Off("QUEST_LOG_UPDATE", headersLater)
    local list = KaLiQuestDevDB and KaLiQuestDevDB.apiChecks
    local entry = type(list) == "table" and list[#list]
    if type(entry) == "table" then
        entry.headers, entry.wrong = looked, wrong
    end
end

-- At login: this build's result, replacing an older one for the same build and version, a few builds kept.
function SelfCheck.AtLogin()
    local result = SelfCheck.Run()
    local d = KaLiQuestDevDB
    if type(d) ~= "table" then
        return
    end
    local _, build = GetBuildInfo()
    local list = type(d.apiChecks) == "table" and d.apiChecks or {}
    for i = #list, 1, -1 do
        if type(list[i]) ~= "table" or list[i].build == build and list[i].version == ns.VERSION then
            table.remove(list, i)
        end
    end
    list[#list + 1] = { build = build, version = ns.VERSION, when = date("%Y-%m-%d %H:%M"), checked = result.checked,
        missing = result.missing, headers = result.headers, wrong = result.wrong }
    while #list > BUILDS_KEPT do
        table.remove(list, 1)
    end
    d.apiChecks = list
    if result.headers == 0 then
        ns.On("QUEST_LOG_UPDATE", headersLater)
    end
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
