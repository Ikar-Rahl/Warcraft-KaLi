-- /kq diag: what the addon sees, live, to diagnose a problem in game. "Copy the report" opens the bug report, which
-- holds all of it and more, ready to paste.
local _, ns = ...
local L = ns.L

local Panel = {}
ns.DebugPanel = Panel

local HEAD = "|cffffd200%s|r"
local BODY_WIDTH = 466
local frame
local countsAtOpen = {}
local sinceUpdate = 0

local function yesNo(v)
    return v and L.YES or L.NO
end

local function trackerState()
    if not ns.db then
        return string.format(L.DIAG_NO_DATA, tostring(ns.disabled))
    end
    if ns.db.options.tracker == false then
        return L.DIAG_OFF
    end
    if ns.Tracker.IsActive() then
        return L.DIAG_SHOWN
    end
    local aside, sections = ns.Coverage.Aside()
    if aside == "manual" then
        return L.DIAG_ASIDE_MANUAL
    elseif aside then
        return string.format(L.DIAG_ASIDE, sections)
    elseif ns.Tracker.failed then
        return L.DIAG_FAILED
    end
    return L.DIAG_OFF
end

local function lastError()
    local count, last, latest = 0, nil, nil
    for msg, e in pairs(KaLiQuestDevDB and KaLiQuestDevDB.errors or {}) do
        count = count + 1
        if not latest or (e.last or "") > latest then
            latest, last = e.last or "", msg
        end
    end
    return count, last and (latest .. "  " .. last:match("^[^\n]*"):sub(1, 120)) or L.DIAG_NONE
end

local function eventLines(add)
    local since = {}
    for event, n in pairs(ns.EventCounts()) do
        local d = n - (countsAtOpen[event] or 0)
        if d > 0 then
            since[#since + 1] = { event = event, n = d }
        end
    end
    table.sort(since, function(a, b)
        return a.n > b.n or (a.n == b.n and a.event < b.event)
    end)
    local parts = {}
    for i = 1, math.min(8, #since) do
        parts[i] = since[i].event .. " " .. since[i].n
    end
    add("  " .. (#parts > 0 and table.concat(parts, " · ") or L.DIAG_NONE))
end

local function sectionLines(add)
    local seen = KaLiQuestDevDB and KaLiQuestDevDB.sectionsSeen or {}
    for _, s in ipairs(ns.Coverage.DRAWN) do
        add("  " .. ns.Coverage.Label(s) .. " : " .. L.DIAG_DRAWN)
    end
    for _, s in ipairs(ns.Coverage.List()) do
        local state = ns.Coverage.State(s.frame)
        local text = state == "kept" and L.DIAG_KEPT or (state == "filled" and L.DIAG_FILLED or L.DIAG_EMPTY)
        if state ~= "empty" then
            text = "|cffff8040" .. text .. "|r"
        end
        local s2 = seen[s.frame]
        if s2 then
            text = text .. string.format(L.DIAG_SEEN, s2.count, s2.last or "?", s2.zone or "?")
        end
        if not (s.module or _G[s.frame]) then
            text = text .. " (" .. L.DIAG_ABSENT .. ")"
        end
        add("  " .. ns.Coverage.Label(s) .. " : " .. text)
    end
end

-- The panel's lines, with colour codes.
function Panel.Lines()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
    end
    local version, build, _, interface = GetBuildInfo()
    add(string.format("%s %s · %s (%s) · %s · %s", ns.TITLE, ns.VERSION, tostring(version), tostring(build), tostring(interface),
        ns.LOCALE))
    add(string.format(L.DIAG_TRACKER, trackerState()))
    add(string.format(L.DIAG_STATE, yesNo(InCombatLockdown()), yesNo(ns.db and ns.Tracker.Shared.isLocked()),
        yesNo(ns.Tracker.Shared.EditMode())))
    local host = ObjectiveTrackerFrame
    if host then
        add(string.format(L.DIAG_HOST, host:IsVisible() and L.DIAG_VISIBLE or L.DIAG_HIDDEN, math.floor(host:GetWidth() + 0.5),
            math.floor(host:GetHeight() + 0.5), yesNo(ns.Host.IsParked())))
    end
    if ns.db then
        local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
        add(string.format(L.DIAG_LIST, #(ns.Tracker.lines or {}), numQuests or 0, C_QuestLog.GetNumQuestWatches() or 0, #ns.db.groups))
    end
    local stats = ns.Tracker.stats
    add(string.format(L.DIAG_REFRESH, stats.count, stats.last, stats.count > 0 and stats.total / stats.count or 0, stats.max))
    local recipes, achievements = ns.Sections.TrackedCounts()
    local buttons = 0
    for _ in pairs(ns.Items.Buttons() or {}) do
        buttons = buttons + 1
    end
    add(string.format(L.DIAG_TRACKED, recipes, achievements, buttons))
    local errors, last = lastError()
    add(string.format(L.DIAG_ERRORS, errors, last))
    local api = ns.SelfCheck.Last()
    if api then
        add(string.format(L.DIAG_API, api.checked, #api.missing))
    end
    local d = KaLiQuestDevDB or {}
    add(string.format(L.DIAG_DEBUG, yesNo(d.debug), yesNo(d.events), yesNo(d.chat), #(d.log or {})))
    add("")
    add(string.format(HEAD, L.DIAG_SECTIONS))
    sectionLines(add)
    add("")
    add(string.format(HEAD, L.DIAG_ITEMS))
    local items = ns.Items.Status()
    for _, it in ipairs(items) do
        add("  " .. it.title .. " : " .. L["ITEM_" .. it.state:upper()])
    end
    if #items == 0 then
        add("  " .. L.DIAG_NONE)
    end
    add("")
    local area, running = ns.Area.Status()
    add(string.format(HEAD, L.DIAG_AREA) .. (running and "" or " : " .. L.DIAG_AREA_OFF))
    for _, a in ipairs(area) do
        add("  " .. a.title .. " : " .. a.signal)
    end
    if running and #area == 0 then
        add("  " .. L.DIAG_NONE)
    end
    add("")
    add(string.format(HEAD, L.DIAG_EVENTS))
    eventLines(add)
    local changes = ns.Coverage.Changes()
    if #changes > 0 then
        add("")
        add(string.format(HEAD, L.DIAG_CHANGES))
        for _, c in ipairs(changes) do
            add("  " .. c)
        end
    end
    -- Debug mode only writes a log, so its last lines show here while it's on.
    local log = d.debug and d.log or {}
    if #log > 0 then
        add("")
        add(string.format(HEAD, L.DIAG_LOG_TAIL))
        for i = math.max(1, #log - 7), #log do
            add("  " .. log[i])
        end
    end
    return lines
end

local buttons = {}

function Panel.Update()
    if not frame then
        return
    end
    frame.Body:SetText(table.concat(Panel.Lines(), "\n"))
    frame.Content:SetHeight(math.max(1, frame.Body:GetStringHeight()))
    buttons.tracker:SetText(ns.Tracker.IsActive() and L.DIAG_TO_BLIZZARD or L.DIAG_TO_KALI)
    local d = KaLiQuestDevDB or {}
    buttons.debug:SetText(L.DIAG_DEBUG_BUTTON .. " : " .. yesNo(d.debug))
    buttons.alert:SetText(L.DIAG_TEST_ALERT .. " : " .. yesNo(ns.Coverage.Simulating()))
end

local function toggleTracker()
    if ns.Tracker.IsActive() then
        ns.Coverage.StepAside()
    elseif ns.db then
        ns.db.options.tracker = true
        ns.Coverage.Resume()
    end
    Panel.Update()
end

local ACTIONS = {
    { key = "copy", text = "DIAG_COPY", fn = function()
        ns.Report.Open()
    end },
    { key = "errors", text = "DIAG_ERRORS_BUTTON", fn = function()
        ns.Debug.ShowText("errors", ns.Debug.ErrorsText())
    end },
    { key = "log", text = "DIAG_LOG", fn = function()
        ns.Debug.ShowText("log", ns.Debug.LogText())
    end },
    { key = "redraw", text = "DIAG_REDRAW", fn = function()
        ns.Coverage.Check()
        ns.RequestRefresh()
    end },
    { key = "tracker", text = "DIAG_TO_BLIZZARD", fn = toggleTracker },
    { key = "debug", text = "DIAG_DEBUG_BUTTON", fn = function()
        if KaLiQuestDevDB then
            KaLiQuestDevDB.debug = not KaLiQuestDevDB.debug
        end
        Panel.Update()
    end },
    { key = "alert", text = "DIAG_TEST_ALERT", fn = function()
        ns.Coverage.Simulate(not ns.Coverage.Simulating())
        Panel.Update()
    end },
}

local function build()
    local function child(kind, template)
        local f = CreateFrame(kind, nil, nil, template)
        f:SetParent(frame)
        return f
    end
    frame = CreateFrame("Frame", "KaLiQuestDebugPanel", nil, "BackdropTemplate")
    frame:SetParent(UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(520, 640)
    frame:SetPoint("CENTER", -260, 0)
    frame:SetBackdrop(BACKDROP_DARK_DIALOG_32_32)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "KaLiQuestDebugPanel")

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", 18, -16)
    frame.Title:SetText(ns.TITLE .. " — " .. L.DIAG_TITLE)
    ns.CloseButton(frame, -6, -6)

    -- With debug on, the lines outgrow the panel, so they scroll above its buttons.
    frame.Scroll = child("ScrollFrame", "UIPanelScrollFrameTemplate")
    frame.Scroll:SetPoint("TOPLEFT", 18, -42)
    frame.Scroll:SetPoint("BOTTOMRIGHT", -36, 104)
    frame.Content = CreateFrame("Frame", nil, nil)
    frame.Content:SetParent(frame.Scroll)
    frame.Content:SetSize(BODY_WIDTH, 1)
    frame.Scroll:SetScrollChild(frame.Content)
    frame.Body = frame.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Body:SetPoint("TOPLEFT")
    frame.Body:SetWidth(BODY_WIDTH)
    frame.Body:SetJustifyH("LEFT")
    frame.Body:SetJustifyV("TOP")

    for i, a in ipairs(ACTIONS) do
        local b = child("Button", "UIPanelButtonTemplate")
        b:SetSize(156, 22)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        b:SetPoint("BOTTOMLEFT", 18 + col * 162, 74 - row * 28)
        b:SetText(L[a.text])
        b:SetScript("OnClick", function()
            ns.SafeCall(a.fn)
        end)
        buttons[a.key] = b
    end

    -- Live while open, twice a second.
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceUpdate = sinceUpdate + (elapsed or 0)
        if sinceUpdate >= 0.5 then
            sinceUpdate = 0
            ns.SafeCall(Panel.Update)
        end
    end)
    frame:SetScript("OnShow", function()
        countsAtOpen = {}
        for event, n in pairs(ns.EventCounts()) do
            countsAtOpen[event] = n
        end
        ns.SafeCall(Panel.Update)
    end)
    frame:Hide()
end

function Panel.Toggle()
    if not frame then
        build()
    end
    frame:SetShown(not frame:IsShown())
end

function Panel.Open()
    if not frame then
        build()
    end
    frame:Show()
    frame:Raise()
end

-- For the offline smoke test.
function Panel.Frames()
    return frame, buttons
end
