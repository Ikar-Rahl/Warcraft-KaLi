-- A small test harness. The same tests run in game (/kq test) and offline (tools/scripts/run_lua_tests.py).
-- They work on fresh tables and a fake world, never on the player's saved layout or tracked list.
KaLiQuestTests = { cases = {} }
local T = KaLiQuestTests

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

function T.Run()
    local debug = KaLiQuestDev.ns.Debug
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
