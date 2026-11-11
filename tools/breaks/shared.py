"""Deliberate breaks of the shared code, each planted in both addons' copies: both addons' tests must catch every one.
Run with: python -I tools/breaks.py tools/breaks/shared.py [word]
"""
CORE, DEBUG, CHECK, REPORT, COMMANDS = (f"shared/addon/{name}.lua" for name in ("Core", "Debug", "SelfCheck", "Report", "Commands"))

BREAKS = [
    # Core
    ("events: a failing handler stops the ones after it", CORE,
     "        ns.SafeCall(copy[i], event, ...)", "        copy[i](event, ...)"),
    ("events: Off leaves the handler in place", CORE, "            table.remove(list, i)", "            local _ = i"),
    ("Call: a game function's answer lost", CORE, "    if ok then\n        return a, b, c\n    end", "    if ok then\n        return nil\n    end"),
    ("SafeCall: an error no longer reaches the debug log", CORE,
     "            ns.Debug.Error(err, debugstack and debugstack(2) or debug.traceback())", "            local _ = err"),
    ("Later: work asked twice in a frame runs twice", CORE, "    if pending[key] then\n        return\n    end\n", ""),
    # Debug
    ("debug: its saved data under another name", DEBUG, '        _G[ns.ADDON .. "DevDB"] = {}', '        _G[ns.ADDON .. "DebugDB"] = {}'),
    ("debug: errors not counted", DEBUG, "        e.count = e.count + 1\n", ""),
    ("debug: the log written with debug mode off", DEBUG,
     "    if not Debug.Enabled() then\n        return\n    end\n    local ok, msg", "    local ok, msg"),
    ("debug: Clear keeps the errors", DEBUG, "    d.log = {}\n    d.errors = {}\n", "    d.log = {}\n"),
    # SelfCheck
    ("self-check: the CVars left unchecked", CHECK, '        { "cvar", needs.cvars, C_CVar and C_CVar.GetCVarInfo },\n', ""),
    ("self-check: an assumption that fails stops the check", CHECK,
     "        local ok, looked, wrong, note = pcall(a[2])", "        local ok, looked, wrong, note = true, a[2]()"),
    ("self-check: told at login, without the addon's own timing", CHECK,
     "    if SelfCheck.AfterLogin then\n        SelfCheck.AfterLogin()\n    else\n        tell()\n    end", "    tell()",
     ("quest",)),
    ("self-check: the same warning again not counted", CHECK,
     "        prev.count, prev.when = (prev.count or 1) + 1, now\n        return\n", ""),
    ("self-check: a blocked action not passed to the addon", CHECK,
     "        if SelfCheck.OnBlocked then\n            SelfCheck.OnBlocked(fn)\n        end\n", ""),
    ("self-check: every build's result kept", CHECK,
     "    while #list > BUILDS_KEPT do\n        table.remove(list, 1)\n    end\n    d.apiChecks = list", "    d.apiChecks = list"),
    # Report
    ("report: the addon's own sections left out", REPORT, "    for _, s in ipairs(Report.Sections) do\n        list[#list + 1] = s\n    end\n", ""),
    ("report: the addon's status lines left out", REPORT,
     "    if Report.StatusLines then\n        lines[#lines + 1] = Report.StatusLines()\n    end\n", ""),
    ("report: colour codes kept", REPORT, ':gsub("|c%x%x%x%x%x%x%x%x", "")', ""),
    ("report: one failing part fails it all", REPORT, "        local ok, text = pcall(s[2])", "        local ok, text = true, s[2]()"),
    ("report: the address never shown", REPORT, "    frame.URL:SetShown(Report.URL ~= nil)", "    frame.URL:SetShown(false)"),
    # Commands
    ("commands: the ones for any time wait for the saved data", COMMANDS,
     "        if not ANYTIME[cmd] and not o.ready() then", "        if not o.ready() then"),
    ("commands: a word no command has goes unanswered", COMMANDS, "            o.unknown(cmd)\n", ""),
    ("commands: the in-game tests' result not kept", COMMANDS, "    ns.DevDB().lastTests = {", "    local _ = {"),
    ("commands: only the first slash command registered", COMMANDS,
     '    for i, slash in ipairs(slashes) do\n        _G["SLASH_" .. id .. i] = slash\n    end', '    _G["SLASH_" .. id .. 1] = slashes[1]'),
    ("commands: debug on leaves it off", COMMANDS, '        d.debug = rest == "on"', "        d.debug = false"),
]
