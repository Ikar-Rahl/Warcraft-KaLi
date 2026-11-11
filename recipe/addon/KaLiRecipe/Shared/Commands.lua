-- Copied from shared/addon/Commands.lua by tools/sync_shared.py: edit the source, not this copy.
-- Slash commands, shared by the KaLi addons: the dispatcher, and the commands every addon has for debugging (debug,
-- log, errors, clear, test, report). The addon's Core/Commands.lua adds its own with Commands.Add, sets
-- ns.Commands.StatusText for /status and the report, then calls Commands.Register.
local ADDON, ns = ...
local L = ns.L

local Commands = {}
ns.Commands = Commands

local say = ns.Say
local COMMANDS = {}
-- Commands that run before the saved data has loaded and been accepted; the others wait for it.
local ANYTIME = {}

-- fn(rest), rest being what follows the command's word. anytime: it doesn't need the saved data.
function Commands.Add(name, fn, anytime)
    COMMANDS[name] = fn
    ANYTIME[name] = anytime or nil
end

function Commands.OnOff(v)
    return v and L.ON or L.OFF
end

local function runTests()
    local loaded, reason = C_AddOns.LoadAddOn(ADDON .. "_Tests")
    local tests = _G[ADDON .. "Tests"]
    if not loaded or not tests then
        say(string.format(L.TESTS_MISSING, tostring(reason)))
        return
    end
    local report = tests.Run()
    ns.DevDB().lastTests = { when = date("%Y-%m-%d %H:%M:%S"), version = ns.VERSION, summary = report.summary, text = report.text }
    say(report.summary)
    ns.Debug.ShowText("tests", report.text)
end

Commands.Add("report", function()
    ns.Report.Open()
end, true)
Commands.Add("debug", function(rest)
    local d = ns.DevDB()
    if rest == "on" or rest == "off" then
        d.debug = rest == "on"
    elseif rest == "events" then
        d.events = not d.events
    elseif rest == "chat" then
        d.chat = not d.chat
    end
    say(string.format(L.DEBUG, Commands.OnOff(d.debug), Commands.OnOff(d.events), Commands.OnOff(d.chat)))
end, true)
Commands.Add("log", function()
    ns.Debug.ShowText("log", ns.Debug.LogText())
end, true)
Commands.Add("errors", function()
    ns.Debug.ShowText("errors", ns.Debug.ErrorsText())
end, true)
Commands.Add("clear", function()
    ns.Debug.Clear()
    say(L.DONE)
end, true)
Commands.Add("test", runTests, true)

-- id: the SlashCmdList key ("KALIQUEST"); slashes: { "/kq", "/kaliquest" }. o.ready() says whether the saved data
-- has loaded and been accepted; o.unknown(word) answers a word no command has.
function Commands.Register(id, slashes, o)
    for i, slash in ipairs(slashes) do
        _G["SLASH_" .. id .. i] = slash
    end
    SlashCmdList[id] = function(input)
        local cmd, rest = (input or ""):match("^[ \t]*([^ \t]*)[ \t]*(.-)[ \t]*$")
        cmd = cmd:lower()
        local fn = COMMANDS[cmd]
        if not fn then
            o.unknown(cmd)
            return
        end
        if not ANYTIME[cmd] and not o.ready() then
            say(string.format(L.DB_REFUSED, tostring(ns.disabled)))
            return
        end
        ns.SafeCall(fn, rest)
    end
end
