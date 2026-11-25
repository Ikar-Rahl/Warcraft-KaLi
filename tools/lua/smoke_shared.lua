-- The shared code's own checks (shared/), run by each addon's runner on that addon's copy, after its smoke session:
-- what the addons run the same way is checked the same way in each. KALI_ADDON names the addon. It runs last: it
-- clears the debug log and adds two failing assumptions. Returns a list of failures.
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
-- An event the client no longer has (a patch took it): registering it is an error in game. The handler is kept, the
-- function that asked goes on, and the event is listed.
F.invalidEvents.KALI_SMOKE_GONE = true
local went = false
local okGone = pcall(function()
    ns.On("KALI_SMOKE_GONE", function() end)
    went = true
end)
F.invalidEvents.KALI_SMOKE_GONE = nil
local listed = false
for _, event in ipairs(ns.MissingEvents()) do
    listed = listed or event == "KALI_SMOKE_GONE"
end
expect(okGone and went and listed, "an event the client no longer has stops the function that registers it, or isn't listed")
-- One the game refuses without an error answers false (the API docs give RegisterEvent a result): listed the same.
-- One it takes isn't.
F.refusedEvents.KALI_SMOKE_REFUSED = true
ns.On("KALI_SMOKE_REFUSED", function() end)
F.refusedEvents.KALI_SMOKE_REFUSED = nil
ns.On("KALI_SMOKE_TAKEN", function() end)
local refused, taken = false, false
for _, event in ipairs(ns.MissingEvents()) do
    refused = refused or event == "KALI_SMOKE_REFUSED"
    taken = taken or event == "KALI_SMOKE_TAKEN"
end
expect(refused, "an event the game refuses without an error isn't listed")
expect(not taken, "an event the game takes is listed as refused")

-- A fight, from its first moment: the game's lockdown starts just after PLAYER_REGEN_DISABLED, so while that event is
-- handled InCombatLockdown() still says no, and ns.InCombat says yes; after the fight both say no.
do
    local atStart, atEnd
    local function onStart()
        atStart = { lockdown = InCombatLockdown(), fight = ns.InCombat() }
    end
    local function onEnd()
        atEnd = { lockdown = InCombatLockdown(), fight = ns.InCombat() }
    end
    ns.On("PLAYER_REGEN_DISABLED", onStart)
    ns.On("PLAYER_REGEN_ENABLED", onEnd)
    local was = F.combat
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    local during = ns.InCombat()
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    F.combat = was
    ns.Off("PLAYER_REGEN_DISABLED", onStart)
    ns.Off("PLAYER_REGEN_ENABLED", onEnd)
    expect(atStart and atStart.lockdown == false and atStart.fight == true and during == true,
        "as a fight starts, before the game's lockdown, ns.InCombat doesn't say it has")
    expect(atEnd and atEnd.fight == false and not ns.InCombat(), "once the fight is over ns.InCombat still says it's on")
    F.RunTimers()
end

-- A window's X in a fight: the game refuses an addon's HideUIPanel then, which the template's own click goes through,
-- so the X hides its window itself (Ikar 2026-11-22, KaLi Recipe's notebook that wouldn't close in a fight).
do
    local window = CreateFrame("Frame", nil, UIParent)
    local close = ns.CloseButton(window, 0, 0)
    window:Show()
    local was, refused = F.combat, #F.panelsRefused
    F.combat = true
    pcall(F.RunScript, close, "OnClick", "LeftButton", false)
    F.combat = was
    expect(not window:IsShown() and #F.panelsRefused == refused, "in a fight a window's X doesn't close it")
end

-- Values the game hides (secret values): ns.Plain gives nil in place of each, every other as it is, however many.
do
    local a, b, c = ns.Plain(1, F.SECRET, "three")
    expect(issecretvalue(F.SECRET) and a == 1 and b == nil and c == "three" and select("#", ns.Plain(1, F.SECRET, "three")) == 3
        and ns.Plain(F.SECRET) == nil and ns.Plain(false) == false and select("#", ns.Plain()) == 0,
        "ns.Plain doesn't give nil for a hidden value and every other as it is")
end

-- A handler run every frame: its first error is kept and takes it off its frame, with what should follow; set again,
-- it runs again.
do
    local frame = CreateFrame("Frame")
    local runs, after = 0, 0
    local function fail()
        runs = runs + 1
        error("smoke_shared: a failing frame handler")
    end
    ns.EveryFrame(frame, fail, function()
        after = after + 1
    end)
    for _ = 1, 4 do
        F.RunScript(frame, "OnUpdate", 0.016)
    end
    local kept
    for msg, e in pairs(dev.errors) do
        if tostring(msg):find("smoke_shared: a failing frame handler", 1, true) then
            kept = e
            dev.errors[msg] = nil
        end
    end
    expect(runs == 1 and after == 1 and frame:GetScript("OnUpdate") == nil and kept and kept.count == 1,
        "a failing every-frame handler comes back every frame: " .. runs .. " runs")
    local seen
    ns.EveryFrame(frame, function(self, elapsed)
        seen = self == frame and elapsed
    end)
    F.RunScript(frame, "OnUpdate", 0.25)
    expect(seen == 0.25, "an every-frame handler isn't given its frame and the time since the last")
    ns.EveryFrame(frame, nil)
    expect(frame:GetScript("OnUpdate") == nil, "an every-frame handler can't be taken off")
    for i = #F.errors, 1, -1 do
        if tostring(F.errors[i]):find("smoke_shared: a failing frame handler", 1, true) then
            table.remove(F.errors, i)
        end
    end
end

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
-- Combat: the click says why, with the game's error line; out of a fight nothing is refused.
local errorsBefore = #F.uiErrors
F.combat = true
local refused = ns.CombatRefused()
F.combat = false
expect(refused and #F.uiErrors == errorsBefore + 1, "in a fight, nothing refused, or nothing said")
expect(not ns.CombatRefused() and #F.uiErrors == errorsBefore + 1, "out of a fight, a refusal")
-- Saved data's numbers: nan and inf aren't finite, whatever this Lua's comparisons say; a copy is a copy all the way
-- down; a count counts; and before saving, every nan and inf goes, as a key or a value, and nothing else.
for _, v in ipairs({ 0 / 0, math.huge, -math.huge, "3", true }) do
    expect(not ns.Finite(v), tostring(v) .. " taken as a finite number")
end
for _, v in ipairs({ 0, -1.5, 2 ^ 31, 1e-300 }) do
    expect(ns.Finite(v), tostring(v) .. " not taken as a finite number")
end
local shared = { 1 }
local original = { a = { b = { 2 } }, s = shared, t = shared }
local copy = ns.DeepCopy(original)
copy.a.b[1] = 3
expect(original.a.b[1] == 2 and copy.s == copy.t and copy.s ~= shared, "a copy that isn't one all the way down")
expect(ns.Count({ 1, 2, x = 3 }) == 3 and ns.Count(nil) == 0, "a count that's wrong")
local dirty = { width = 0 / 0, [math.huge] = 1, keep = 2, inner = { -math.huge, 5 } }
dirty.loop = dirty
expect(ns.DropNonFinite(dirty) == 3, "the numbers a file can't hold not all counted")
expect(dirty.width == nil and dirty[math.huge] == nil and dirty.keep == 2 and dirty.inner[1] == nil and dirty.inner[2] == 5
    and dirty.loop == dirty, "the numbers a file can't hold not all taken out, or more taken")

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
-- At logout the debug table keeps no number its file can't hold either. The addon's own logout, as the game fires it
-- (its other handlers write what they write at any logout).
dev.kaliSmokeNumber = 0 / 0
ns.Fire("PLAYER_LOGOUT")
expect(dev.kaliSmokeNumber == nil and type(dev.log) == "table", "at logout, a nan left in the debug table")
-- An event's values go to the log while events are traced: one the game hides (a secret value: a chat line's text in
-- a dungeon) is named there, never read, which would be an error for every handler of that event.
do
    local debugWas, eventsWas, errorsWas = dev.debug, dev.events, ns.Count(dev.errors)
    dev.debug, dev.events = true, true
    local heardSecret = false
    local function hear(_, _, value)
        heardSecret = issecretvalue(value)
    end
    ns.On("KALI_SMOKE_SECRET", hear)
    local traced = pcall(F.Fire, "KALI_SMOKE_SECRET", "seen", F.SECRET, 3)
    ns.Off("KALI_SMOKE_SECRET", hear)
    local line = dev.log[#dev.log] or ""
    dev.debug, dev.events = debugWas, eventsWas
    expect(traced and heardSecret and ns.Count(dev.errors) == errorsWas
        and line:find('KALI_SMOKE_SECRET "seen", (secret), 3', 1, true),
        "an event carrying a hidden value can't be traced, or doesn't reach its handlers: " .. line)
end
-- A window dragged by its body leaves nothing for the game's own layout file: its place isn't the game's to save, and
-- once let go the game doesn't take it for placed by the player. What follows the drag is told.
do
    local stopped
    local window = CreateFrame("Frame", "KaLiSmokeWindow")
    ns.Movable(window, function(f)
        stopped = f
    end)
    F.RunScript(window, "OnDragStart", "LeftButton")
    local moving = window.moving
    F.RunScript(window, "OnDragStop")
    expect(moving and not window.moving and stopped == window and window.dontSavePosition == true and window.userPlaced == false,
        "a window dragged by its body is left for the game to keep in its layout file, or its drag isn't told")
    _G.KaLiSmokeWindow = nil
    -- The debug log's own window, dragged.
    ns.Debug.ShowText("smoke", "smoke_shared")
    local textWindow = _G[ADDON .. "TextWindow"]
    F.RunScript(textWindow, "OnDragStart", "LeftButton")
    F.RunScript(textWindow, "OnDragStop")
    textWindow:Hide()
end

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
-- One that gives back no list is reported too, and doesn't take the check down.
ns.SelfCheck.Add("kali smoke: no list", function()
    return "some", nil, 3
end)
local ok
ok, result = pcall(ns.SelfCheck.Run)
local noList
for _, a in ipairs(ok and result.assumed or {}) do
    if a.name == "kali smoke: no list" then
        noList = a
    end
end
expect(noList and noList.looked == 0 and noList.note == "3" and noList.wrong[1]:find("no list", 1, true),
    "an assumption that gives back no list takes the check down, or isn't reported")
expect(ok and ns.Report.Text():find("kali smoke: no list: looked at 0, 3", 1, true), "and the report's part with it")
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
-- An event the game refused as the addon registered it is named by the API check, whatever the game says of the event
-- now; one the check finds gone as well is named once.
local refusals, goneTwice = 0, 0
for _, m in ipairs(result.missing) do
    refusals = refusals + ((m == "event KALI_SMOKE_GONE (registration refused)" or m == "event KALI_SMOKE_REFUSED (registration refused)") and 1 or 0)
end
expect(refusals == 2, "an event the game refused to register isn't named by the API check, once: " .. refusals)
local needed = ns.NEEDS.events
ns.NEEDS.events = { "KALI_SMOKE_GONE" }
F.invalidEvents.KALI_SMOKE_GONE = true
result = ns.SelfCheck.Run()
F.invalidEvents.KALI_SMOKE_GONE = nil
ns.NEEDS.events = needed
for _, m in ipairs(result.missing) do
    goneTwice = goneTwice + (m:find("KALI_SMOKE_GONE", 1, true) and 1 or 0)
end
expect(goneTwice == 1, "an event gone from the game and refused at registration is named " .. goneTwice .. " times, not once")
-- At login, a few builds are kept.
local checks = dev.apiChecks
dev.apiChecks = {}
for i = 1, 7 do
    dev.apiChecks[i] = { build = "old" .. i, version = "old" }
end
ns.SelfCheck.AtLogin()
expect(#dev.apiChecks == 5, "the API check keeps " .. #dev.apiChecks .. " builds, not 5")
-- What didn't hold when the chat said so is kept with the build's entry, and in the report, though it holds since: the
-- assumptions run again later (KaLi Quest's at each zone change), and what they find then replaces what they found.
do
    local holds, afterLogin = false, ns.SelfCheck.AfterLogin
    ns.SelfCheck.Add("kali smoke: holds later", function()
        return 1, holds and {} or { "not yet" }
    end)
    ns.SelfCheck.AfterLogin = nil
    dev.apiChecks = {}
    ns.SelfCheck.AtLogin()
    holds = true
    ns.SelfCheck.Store()
    local entry, said, still = dev.apiChecks[#dev.apiChecks], {}, false
    for _, w in ipairs(type(entry.told) == "table" and entry.told.what or {}) do
        said[w] = true
    end
    for _, a in ipairs(entry.assumed) do
        still = still or a.name == "kali smoke: holds later" and #a.wrong > 0
    end
    expect(not still and said["kali smoke: holds later: not yet"], "what didn't hold when the chat said so isn't kept")
    expect(ns.Report.Text():find("\n      kali smoke: holds later: not yet", 1, true),
        "what didn't hold when the chat said so isn't in the report")
    ns.SelfCheck.AfterLogin = afterLogin
end
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
extra[#extra + 1] = { "kali smoke fence", function()
    return "kali smoke ``` fence"
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
expect(text:find("kali smoke ''' fence", 1, true) and not text:find("```", 1, true),
    "the report holds a ```, which would close the block the issue pastes it in")
-- The link: a new issue, its title to finish, a line asking what happened, a block to paste the report in. Never the
-- report itself, which runs past what a link carries (Ikar, 2026-11-11), and only what an address carries.
local L = ns.L
local function decode(s)
    return (s:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end
local url = ns.Report.URL
ns.Report.URL = url or "https://example.invalid/issues/new"
local base = ns.Report.URL .. "?title="
local link = ns.Report.Link()
local body = decode(link and link:match("&body=(.*)$") or "")
expect(link and link:sub(1, #base) == base, "the link isn't a new issue's address")
expect(decode(link and link:match("%?title=([^&]*)") or "") == ns.TITLE .. " " .. ns.VERSION .. ": ",
    "the link's title isn't the addon and its version, to finish")
expect(body == L.REPORT_ASK .. "\n\n\n```text\n" .. L.REPORT_PASTE .. "\n```\n",
    "the link's body doesn't ask what happened, then give a block to paste the report in, and nothing more")
expect(link and #link <= 1000, "the link runs past what every browser and GitHub's sign-in keep: " .. tostring(link and #link))
-- Spelt out, as %w may take a byte of « é » for a letter.
expect(link and not link:find("[^A-Za-z0-9%-%._~%%:/?&=]"), "the link holds a character an address can't carry, or a |")
-- Its window shows the link, then the whole report, each to copy, or says there's no address yet.
ns.Report.Open()
local frame = ns.Report.Frame()
F.RunScript(frame, "OnDragStart", "LeftButton")
F.RunScript(frame, "OnDragStop")
expect(frame.URL:IsShown() and frame.LinkCopy:IsShown() and not frame.NoURL:IsShown() and frame.URL:GetText() == link
    and frame.Copy:IsShown() and frame.Box:GetText():find("== status ==", 1, true),
    "the report's window doesn't show the link, then the report")
F.focus = nil
F.RunScript(frame.LinkCopy, "OnClick", "LeftButton")
expect(F.focus == frame.URL and frame.URL.highlighted and frame.LinkHint:GetText() == L.REPORT_PRESS_COPY,
    "the link's button doesn't select it for Ctrl+C")
F.ctrl = true
F.RunScript(frame.URL, "OnKeyDown", "C")
F.ctrl = false
F.RunTimers()
expect(F.focus ~= frame.URL and frame.LinkHint:GetText() == L.REPORT_LINK_COPIED,
    "after Ctrl+C the link's box doesn't let go of the keyboard, or say what to do next")
ns.Report.URL = nil
ns.Report.Open()
expect(frame.NoURL:IsShown() and not frame.URL:IsShown() and not frame.LinkCopy:IsShown() and ns.Report.Link() == nil,
    "with no address, the report's window doesn't say so")
ns.Report.URL = url
-- The mailbox, for a player without a GitHub account (2026-11-24): its address under the link, a click selecting it
-- for Ctrl+C, the report's button under it; no line for it without one.
local mail = ns.Report.MAIL
ns.Report.MAIL = "reports@example.invalid"
ns.Report.Open()
expect(frame.MailText:IsShown() and frame.MailText:GetText() == L.REPORT_MAIL and frame.Mail:IsShown()
    and frame.Mail:GetText() == "reports@example.invalid" and select(2, frame.Copy:GetPoint(1)) == frame.Mail,
    "the report's window doesn't give the address to mail the report to, above the report's button")
F.RunScript(frame.Mail, "OnEditFocusGained")
expect(frame.Mail.highlighted and frame.MailHint:GetText() == L.REPORT_PRESS_COPY,
    "a click on the mailbox's address doesn't select it for Ctrl+C")
F.focus = frame.Mail
F.ctrl = true
F.RunScript(frame.Mail, "OnKeyDown", "C")
F.ctrl = false
F.RunTimers()
expect(F.focus ~= frame.Mail and frame.MailHint:GetText() == L.REPORT_MAIL_COPIED,
    "after Ctrl+C the mailbox's address doesn't let go of the keyboard, or say what to do next")
ns.Report.MAIL = nil
ns.Report.Open()
expect(not frame.MailText:IsShown() and not frame.Mail:IsShown() and select(2, frame.Copy:GetPoint(1)) == frame.LinkCopy,
    "with no mailbox, its lines still show, or the report's button isn't under the link's")
ns.Report.MAIL = mail
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
expect(dev.lastTests and dev.lastTests.build == select(2, GetBuildInfo())
    and ns.Report.Text():find("build " .. select(2, GetBuildInfo()) .. ": PASS 1/1 kali smoke", 1, true),
    "the in-game tests' result isn't kept with the game's build, or the report doesn't say it")
dev.lastTests = last
F.RunTimers()

-- ---------- Dialog ----------
-- A label broken by hand, as Blizzard's German breaks a word too long for the label's 100 ("Symbol-\nabstand"): the
-- label keeps its break, the tooltip's title has the word whole.
do
    local values = { size = 3 }
    local handle = ns.Dialog.New({
        title = "kali smoke",
        open = "one",
        sections = function()
            return { { id = "one", name = "One", rows = {
                { kind = "slider", key = "size", name = "Fortschritts-\nleisten", step = 1, tip = "kali smoke: why" },
            } } }
        end,
        options = function()
            return values
        end,
        defaults = { size = 3 },
        ranges = { size = { 0, 10 } },
    })
    handle:Open()
    local row = handle.frame.rows[1]
    expect(row.Label:GetText() == "Fortschritts-\nleisten", "dialog: a label's own line break is lost")
    F.RunScript(row, "OnEnter")
    expect(F.tooltip.lines[1] == "Fortschrittsleisten" and F.tooltip.lines[2] == "kali smoke: why",
        "dialog: a label broken by hand is broken in its tooltip's title too: " .. tostring(F.tooltip.lines[1]))
    F.RunScript(row, "OnLeave")
    handle:Close()
end

-- A section's own « Annuler » and « Par défaut » (spec.sectionButtons), on one line under its rows: each changes its
-- section's values alone, « Annuler » its own extra too, asking nothing; each lit only when it has something to do.
do
    local values, held = { a = 5, b = true, c = 7 }, { place = "home" }
    local handle = ns.Dialog.New({
        title = "kali smoke",
        open = "one",
        sections = function()
            return {
                { id = "one", name = "One", rows = {
                    { kind = "slider", key = "a", name = "A", step = 1 },
                    { kind = "check", key = "b", name = "B" },
                }, extra = {
                    take = function()
                        return { held.place }
                    end,
                    same = function(h)
                        return h[1] == held.place
                    end,
                    put = function(h)
                        held.place = h[1]
                    end,
                } },
                { id = "two", name = "Two", rows = { { kind = "slider", key = "c", name = "C", step = 1 } } },
            }
        end,
        options = function()
            return values
        end,
        defaults = { a = 3, b = false, c = 2 },
        ranges = { a = { 0, 10 }, c = { 0, 10 } },
        sectionButtons = { revert = { text = "Annuler" }, defaults = { text = "Par défaut" } },
    })
    handle:Open()
    handle:Snapshot()
    local function line(id)
        for _, f in ipairs(handle.frame.rows) do
            if f.section.id == id and f.row.kind == "buttons" then
                return f
            end
        end
    end
    local one, two, sections = line("one"), line("two"), handle:Sections()
    expect(one and two and one:IsShown() and not two:IsShown() and one.Revert:GetParent() == one
        and one.Defaults:GetParent() == one and not one.Revert:IsEnabled() and one.Defaults:IsEnabled(),
        "dialog: a section's « Annuler » and « Par défaut » aren't on one line of the open section, or aren't lit as they should be")
    handle:Set(sections[1].rows[1], 8)
    handle:Set(sections[2].rows[1], 9)
    held.place = "dragged"
    expect(one.Revert:IsEnabled(), "dialog: a section's « Annuler » stays grey once its value changed")
    F.RunScript(one.Revert, "OnClick")
    expect(values.a == 5 and values.c == 9 and held.place == "home" and not one.Revert:IsEnabled(),
        "dialog: a section's « Annuler » doesn't put back its own values and extra alone")
    F.RunScript(one.Defaults, "OnClick")
    expect(values.a == 3 and values.b == false and values.c == 9 and not one.Defaults:IsEnabled(),
        "dialog: a section's « Par défaut » doesn't set its own values alone")
    handle:Close()
end

-- ---------- Page ----------
-- A button's click may change what a box of the page shows without telling the page: it draws its boxes again by
-- itself. (Each addon's own buttons tell it as well, which hid a break of this in their sessions.)
do
    local page = ns.Options and ns.Options.page
    local box, button
    if page and page.category then
        F.PickSettingsPage(page.category)
        for _, f in ipairs(page.frame.rows or {}) do
            box = box or (f.Check and f)
            button = button or (f.Button and f)
        end
    end
    if box and button then
        local get, click, on = box.row.get, button.row.click, false
        box.row.get = function()
            return on
        end
        button.row.click = function()
            on = true
        end
        page:Refresh()
        local before = box.Check:GetChecked()
        F.RunScript(button.Button, "OnClick")
        expect(before == false and box.Check:GetChecked() == true,
            "page: a button's click changed what a box shows, and the box isn't drawn again")
        box.row.get, button.row.click = get, click
        page:Refresh()
    end
end

-- ---------- The whole session ----------
-- Of every window the addon let the player drag or size, in its own session and here, none is left for the game to
-- keep in its layout file; and the game blocked nothing the addon did.
expect(#F.Placed() == 0, "a window's place is left for the game to keep in its layout file: " .. table.concat(F.Placed(), ", "))
expect(#F.blocked == 0, "the game blocked an action of the addon's: " .. table.concat(F.blocked, ", "))

return failures
