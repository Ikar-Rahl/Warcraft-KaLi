-- The shared code's own checks (shared/), run by each addon's runner on that addon's copy, after its smoke session:
-- what both addons run the same way is checked the same way in both. KALI_ADDON names the addon. It runs last: it
-- clears the debug log and adds a failing assumption. Returns a list of failures.
local F = FakeWoW
local ADDON = KALI_ADDON
local ID = ADDON:upper()
local ns = _G[ADDON .. "Dev"].ns
local dev = ns.DevDB()
local failures = {}

local function expect(ok, what)
    if not ok then
        failures[#failures + 1] = "shared: " .. what
    end
end

local function printedSince(mark, text)
    for i = mark + 1, #F.printed do
        if not text or F.printed[i]:find(text, 1, true) then
            return true
        end
    end
    return false
end

-- ---------- Core ----------
-- Events: a handler that fails doesn't stop the ones after it, and goes to the debug log's errors.
local heard = {}
local function failing()
    error("smoke_shared: a failing handler")
end
local function second(_, value)
    heard[#heard + 1] = value
end
ns.On("KALI_SMOKE_EVENT", failing)
ns.On("KALI_SMOKE_EVENT", second)
F.Fire("KALI_SMOKE_EVENT", 1)
expect(heard[1] == 1, "a failing event handler stops the ones after it")
local caught
for msg in pairs(dev.errors) do
    if tostring(msg):find("smoke_shared: a failing handler", 1, true) then
        caught = msg
    end
end
expect(caught ~= nil, "a failing event handler's error reaches the debug log")
-- The same error again counts once more, in the same entry.
if caught then
    local before = dev.errors[caught].count
    F.Fire("KALI_SMOKE_EVENT", 2)
    expect(dev.errors[caught].count == before + 1, "an error seen again is counted")
    dev.errors[caught] = nil
end
-- Off: the handler hears nothing more; with none left, the event goes.
ns.Off("KALI_SMOKE_EVENT", second)
local count = #heard
F.Fire("KALI_SMOKE_EVENT", 3)
expect(#heard == count, "a handler taken off still hears its event")
ns.Off("KALI_SMOKE_EVENT", failing)
for msg in pairs(dev.errors) do
    if tostring(msg):find("smoke_shared: a failing handler", 1, true) then
        dev.errors[msg] = nil
    end
end
-- Later: asked twice in one frame, the work runs once, on the next frame.
local runs = 0
ns.Later("kaliSmoke", function()
    runs = runs + 1
end)
ns.Later("kaliSmoke", function()
    runs = runs + 1
end)
expect(runs == 0, "work asked for later runs at once")
F.RunTimers()
expect(runs == 1, "work asked twice in a frame runs " .. runs .. " times")

-- ---------- Debug ----------
local wasDebug = dev.debug
dev.debug = false
local lines = #dev.log
ns.Debug.Log("smoke", "with debug mode off")
expect(#dev.log == lines, "the debug log is written with debug mode off")
dev.debug = true
ns.Debug.Log("smoke", "with debug mode on")
expect(#dev.log == lines + 1, "the debug log isn't written with debug mode on")
dev.debug = wasDebug
dev.errors["smoke_shared: kept"] = { count = 1 }
ns.Debug.Clear()
expect(next(dev.errors) == nil and #dev.log == 0, ns.SLASH .. " clear keeps something")

-- ---------- SelfCheck ----------
-- An assumption that fails to run is reported, and the others still run.
ns.SelfCheck.Add("kali smoke: fails", function()
    error("smoke_shared: a check that fails")
end)
local result = ns.SelfCheck.Run()
local failed
for _, a in ipairs(result.assumed) do
    if a.name == "kali smoke: fails" then
        failed = a.wrong[1]
    end
end
expect(failed and failed:find("the check failed", 1, true), "an assumption that fails to run isn't reported")
-- The needs list's CVars are looked for.
local cvars = ns.NEEDS.cvars
ns.NEEDS.cvars = { "KaLiSmokeNoSuchCVar" }
result = ns.SelfCheck.Run()
ns.NEEDS.cvars = cvars
local missing = false
for _, m in ipairs(result.missing) do
    missing = missing or m == "cvar KaLiSmokeNoSuchCVar"
end
expect(missing, "a CVar the game lacks isn't seen missing")
-- At login, a few builds are kept.
local checks = dev.apiChecks
dev.apiChecks = {}
for i = 1, 7 do
    dev.apiChecks[i] = { build = "old" .. i, version = "old" }
end
ns.SelfCheck.AtLogin()
expect(#dev.apiChecks == 5, "the API check keeps " .. #dev.apiChecks .. " builds, not 5")
dev.apiChecks = checks
-- The game's warnings against the addon: the same one twice is one entry counted twice; a blocked action reaches the
-- addon's own hook.
local warnings = dev.gameWarnings
dev.gameWarnings = {}
F.Fire("LUA_WARNING", 0, "Interface/AddOns/" .. ADDON .. "/Smoke.lua:1: smoke")
F.Fire("LUA_WARNING", 0, "Interface/AddOns/" .. ADDON .. "/Smoke.lua:1: smoke")
expect(#dev.gameWarnings == 1 and dev.gameWarnings[1].count == 2, "the same game warning twice isn't counted once")
local onBlocked, blocked = ns.SelfCheck.OnBlocked, nil
ns.SelfCheck.OnBlocked = function(fn)
    blocked = fn
end
F.Fire("ADDON_ACTION_BLOCKED", ADDON, "KaLiSmokeFunction()")
ns.SelfCheck.OnBlocked = onBlocked
expect(blocked == "KaLiSmokeFunction()", "a blocked action doesn't reach the addon")
dev.gameWarnings = warnings

-- ---------- Report ----------
-- The addon's status lines and sections are in it, colour codes aren't, and a part that fails leaves the others.
local sections = ns.Report.Sections
local extra = {}
for i, s in ipairs(sections) do
    extra[i] = s
end
extra[#extra + 1] = { "kali smoke colour", function()
    return "|cffff0000kali smoke red|r"
end }
extra[#extra + 1] = { "kali smoke broken", function()
    error("smoke_shared: a broken part")
end }
ns.Report.Sections = extra
local text = ns.Report.Text()
ns.Report.Sections = sections
for _, s in ipairs(sections) do
    expect(text:find("== " .. s[1] .. " ==", 1, true), "the report leaves out its section " .. s[1])
end
if ns.Report.StatusLines then
    local first = ns.Report.StatusLines():match("^[^\n]*")
    expect(text:find(first, 1, true), "the report leaves out the addon's status lines")
end
expect(text:find("kali smoke red", 1, true) and not text:find("|cffff0000", 1, true), "the report keeps colour codes")
expect(text:find("(failed:", 1, true) and text:find("== addons ==", 1, true), "a part that fails breaks the report")
-- Its window shows the address to post at, or says there's none yet.
ns.Report.Open()
local frame = ns.Report.Frame()
if ns.Report.URL then
    expect(frame.URL:IsShown() and not frame.NoURL:IsShown() and frame.URL:GetText() == ns.Report.URL,
        "the report's window doesn't show its address")
else
    expect(frame.NoURL:IsShown() and not frame.URL:IsShown(), "with no address, the report's window doesn't say so")
end
frame:Hide()

-- ---------- Commands ----------
local slash = SlashCmdList[ID]
expect(_G["SLASH_" .. ID .. "1"] and _G["SLASH_" .. ID .. "2"], "the addon's second slash command isn't registered")
-- The commands for debugging run before the saved data is accepted; a word no command has gets an answer.
local db, mark = ns.db, #F.printed
ns.db = nil
slash("log")
ns.db = db
expect(not printedSince(mark, "|r"), "/log waits for the saved data")
mark = #F.printed
slash("kalismokenosuchcommand")
expect(printedSince(mark), "a word no command has gets no answer")
wasDebug = dev.debug
slash("debug on")
expect(dev.debug == true, "debug on leaves it off")
slash(wasDebug and "debug on" or "debug off")
-- The in-game tests' result is kept, for the report.
local tests, last = _G[ADDON .. "Tests"], dev.lastTests
_G[ADDON .. "Tests"] = { Run = function()
    return { summary = "PASS 1/1 kali smoke", text = "", passed = 1, failed = 0 }
end }
slash("test")
_G[ADDON .. "Tests"] = tests
expect(dev.lastTests and dev.lastTests.summary == "PASS 1/1 kali smoke", "the in-game tests' result isn't kept")
dev.lastTests = last
F.RunTimers()

return failures
