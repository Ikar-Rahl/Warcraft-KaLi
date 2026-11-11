-- Copied from shared/tests/Harness.lua by tools/sync_shared.py: edit the source, not this copy.
-- A small test harness, shared by the KaLi addons' tests. The same tests run in game (/kq test, /kr test) and offline
-- (each addon's tools/run_tests.py). They work on fresh tables and a fake world, never on the player's saved data.
-- Loaded first by <Addon>_Tests, it makes <Addon>Tests, which the test files add to.
local ADDON = ...
local BASE = ADDON:gsub("_Tests$", "")

local T = { cases = {} }
_G[BASE .. "Tests"] = T

function T.Add(suite, name, fn)
    T.cases[#T.cases + 1] = { suite = suite, name = name, fn = fn }
end

local function show(v)
    if type(v) == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end

function T.Eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", show(expected), show(actual)), 2)
    end
end

function T.True(value, what)
    if not value then
        error(what or "expected true", 2)
    end
end

-- Two arrays with the same values in the same order.
function T.List(actual, expected, what)
    local a, e = {}, {}
    for i, v in ipairs(actual or {}) do
        a[i] = show(v)
    end
    for i, v in ipairs(expected) do
        e[i] = show(v)
    end
    local as, es = table.concat(a, ", "), table.concat(e, ", ")
    if as ~= es then
        error(string.format("%s: expected {%s}, got {%s}", what or "list", es, as), 2)
    end
end

-- The first difference between two values, nested tables compared key by key (raw: a table's defaults read through
-- don't count), as "path: expected, got"; nil when they're the same.
local function diff(expected, actual, path)
    if type(expected) ~= "table" or type(actual) ~= "table" then
        if expected ~= actual and not (expected ~= expected and actual ~= actual) then
            return string.format("%s: expected %s, got %s", path, show(expected), show(actual))
        end
        return nil
    end
    for k, v in pairs(expected) do
        local d = diff(v, rawget(actual, k), path .. "." .. tostring(k))
        if d then
            return d
        end
    end
    for k, v in pairs(actual) do
        if rawget(expected, k) == nil then
            return string.format("%s.%s: not expected, got %s", path, tostring(k), show(v))
        end
    end
    return nil
end
T.Diff = diff

function T.Same(actual, expected, what)
    local d = diff(expected, actual, what or "value")
    if d then
        error(d, 2)
    end
end

-- A saved variable as the game writes it at logout: an assignment, keys in brackets, tables inline. Only what the game
-- keeps: strings, numbers, booleans and tables (a function, or a metatable, is lost). Whole numbers as they are,
-- others to 17 digits, so they read back the same; nan and inf as the C library prints them, which don't. Keys
-- sorted, so the same data is the same text.
function T.Saved(name, value)
    local out = { name, " = " }
    local function number(v)
        if tostring(v):find("[^%d%.,eE%+%-]") then
            return tostring(v) -- nan or inf, as this C library prints it (not by comparing: the game's Lua can't)
        elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then
            return string.format("%.0f", v)
        end
        return string.format("%.17g", v)
    end
    local keep = { string = true, number = true, boolean = true, table = true }
    local function write(v)
        local t = type(v)
        if t == "string" then
            out[#out + 1] = string.format("%q", v)
        elseif t == "number" then
            out[#out + 1] = number(v)
        elseif t == "boolean" then
            out[#out + 1] = tostring(v)
        else
            out[#out + 1] = "{\n"
            local keys = {}
            for k, x in pairs(v) do
                if keep[type(k)] and type(k) ~= "table" and keep[type(x)] then
                    keys[#keys + 1] = k
                end
            end
            table.sort(keys, function(a, b)
                if type(a) ~= type(b) then
                    return type(a) == "number"
                elseif type(a) == "boolean" then
                    return not a and b
                end
                return a < b
            end)
            for _, k in ipairs(keys) do
                out[#out + 1] = "["
                if type(k) == "string" then
                    out[#out + 1] = string.format("%q", k)
                elseif type(k) == "number" then
                    out[#out + 1] = number(k)
                else
                    out[#out + 1] = tostring(k)
                end
                out[#out + 1] = "] = "
                write(v[k])
                out[#out + 1] = ",\n"
            end
            out[#out + 1] = "}"
        end
    end
    write(value)
    out[#out + 1] = "\n"
    return table.concat(out)
end

-- What the game reads back from a saved file: its variables, or nil and the error that loses the whole file.
function T.ReadSaved(text)
    local chunk, err = loadstring(text, "=saved file")
    if not chunk then
        return nil, err
    end
    local env = {}
    setfenv(chunk, env)
    local ok, runErr = pcall(chunk)
    if not ok then
        return nil, runErr
    end
    return env
end

function T.Run()
    local debug = _G[BASE .. "Dev"].ns.Debug
    local wasMuted = debug.muted
    debug.muted = true
    local lines, passed, failed = {}, 0, 0
    for _, case in ipairs(T.cases) do
        local ok, err = xpcall(case.fn, function(e)
            return tostring(e)
        end)
        if ok then
            passed = passed + 1
            lines[#lines + 1] = "PASS  " .. case.suite .. ": " .. case.name
        else
            failed = failed + 1
            lines[#lines + 1] = "FAIL  " .. case.suite .. ": " .. case.name .. "\n      " .. tostring(err)
        end
    end
    debug.muted = wasMuted
    local summary = string.format("%s %d/%d", failed == 0 and "PASS" or "FAIL", passed, passed + failed)
    table.insert(lines, 1, summary)
    return { summary = summary, text = table.concat(lines, "\n"), passed = passed, failed = failed }
end
