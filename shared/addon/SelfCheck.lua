-- The API check, shared by the KaLi addons: what the addon takes from the game, looked for in this client (the list in
-- Data/Needs.lua, made offline from the code), and what it assumes of the game's answers, tried on the player's own
-- game (Ikar's ruling for KaLi Quest: every assumption about the game is covered by a test). Run at login, kept per
-- build in <Addon>DevDB.apiChecks, and again for each bug report. It changes nothing, but says once in chat when
-- something isn't as assumed. Also keeps what the game reports against the addon: a blocked action, a Lua warning in
-- its files.
--
-- The addon's Core/SelfCheck.lua adds its assumptions with SelfCheck.Add(name, fn), fn returning how many things it
-- looked at, the list of what didn't hold, and a note. It may set SelfCheck.AfterLogin, run at login in place of
-- telling at once (KaLi Quest waits for its quest log), and SelfCheck.OnBlocked(fn), told of each action the game
-- blocked.
local ADDON, ns = ...

local SelfCheck = {}
ns.SelfCheck = SelfCheck

local BUILDS_KEPT = 5
local WARNINGS_KEPT = 20

-- A dotted global's value: "Enum.ItemClass.Recipe".
function SelfCheck.Resolve(name)
    local value = _G
    for part in name:gmatch("[^.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end
local resolve = SelfCheck.Resolve

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

local ASSUMPTIONS = {}

function SelfCheck.Add(name, fn)
    ASSUMPTIONS[#ASSUMPTIONS + 1] = { name, fn }
end

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

local last

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

local current -- this build's entry in <Addon>DevDB.apiChecks, from login

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

-- Brings this build's entry, and the report's copy, up to date with the assumptions as they stand.
function SelfCheck.Store()
    if not current then
        return
    end
    current.assumed, current.failing = SelfCheck.Assumptions()
    if last then
        last.assumed, last.failing = current.assumed, current.failing
    end
    tell()
end

-- At login: this build's result, replacing an older one for the same build and version but not whether it was said,
-- a few builds kept.
function SelfCheck.AtLogin()
    local result = SelfCheck.Run()
    local d = ns.DevDB()
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
    if SelfCheck.AfterLogin then
        SelfCheck.AfterLogin()
    else
        tell()
    end
end

-- A report like the last one adds to its count.
local function note(kind, text)
    local d = ns.DevDB()
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
    local d = ns.DevDB()
    local list = type(d) == "table" and d.gameWarnings
    for _, w in ipairs(type(list) == "table" and list or {}) do
        lines[#lines + 1] = string.format("%s  %s  x%d  %s", tostring(w.when), tostring(w.kind), w.count or 1, tostring(w.text))
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end

-- The game names the addon it blames, and a warning names the file.
ns.On("ADDON_ACTION_BLOCKED", function(_, addon, fn)
    if addon == ADDON then
        note("blocked", fn)
        if SelfCheck.OnBlocked then
            SelfCheck.OnBlocked(fn)
        end
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
