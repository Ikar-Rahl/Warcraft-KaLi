-- What the addon takes from the game, looked for in this client: the list in Data/Needs.lua, made from the code
-- offline. Run at login, kept per build in KaLiQuestDevDB.apiChecks, and again for each bug report; it changes
-- nothing. Also keeps what the game reports against the addon: an action it blocked, a Lua warning in its files.
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

-- { checked, skipped, missing = { "kind name", sorted } } for this client now.
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
    last = result
    return result
end

function SelfCheck.Last()
    return last
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
        missing = result.missing }
    while #list > BUILDS_KEPT do
        table.remove(list, 1)
    end
    d.apiChecks = list
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
