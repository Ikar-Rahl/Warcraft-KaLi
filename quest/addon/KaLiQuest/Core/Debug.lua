-- Debug mode: a log kept in saved data, error capture, event tracing and a window to copy text from.
-- Account-wide in KaLiQuestDevDB, so one file holds it for every character.
local _, ns = ...

local Debug = {}
ns.Debug = Debug

local LOG_MAX = 3000
local TRIM = 300
local ERRORS_MAX = 100
local OTHER_ERRORS = "(more distinct errors than are kept)"
local reportedThisSession = false

-- Set while the in-game tests run, so their model actions stay out of the log.
Debug.muted = false

local function dev()
    return KaLiQuestDevDB
end

function Debug.Init()
    if type(KaLiQuestDevDB) ~= "table" then
        KaLiQuestDevDB = {}
    end
    local d = KaLiQuestDevDB
    d.debug = d.debug == true
    d.events = d.events == true
    d.chat = d.chat == true
    if type(d.log) ~= "table" then
        d.log = {}
    end
    if type(d.errors) ~= "table" then
        d.errors = {}
    end
end

function Debug.Enabled()
    local d = dev()
    return d and d.debug and not Debug.muted
end

local function stamp()
    return string.format("%s %8.3f", date("%H:%M:%S"), GetTime())
end

local function push(line)
    local log = dev().log
    log[#log + 1] = line
    if #log > LOG_MAX + TRIM then
        local keep = {}
        for i = #log - LOG_MAX + 1, #log do
            keep[#keep + 1] = log[i]
        end
        dev().log = keep
    end
end

-- Debug.Log("model", "moved %d to %s", id, name). Free when debug mode is off.
function Debug.Log(category, fmt, ...)
    if not Debug.Enabled() then
        return
    end
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    if not ok then
        msg = tostring(fmt)
    end
    push(stamp() .. " [" .. category .. "] " .. msg)
    if dev().chat then
        print("|cff7fbfffKQ " .. category .. "|r " .. msg)
    end
end

local function describe(v)
    if type(v) == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end

function Debug.TraceEvent(event, ...)
    local d = dev()
    if not (d and d.debug and d.events) or Debug.muted then
        return
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = describe((select(i, ...)))
    end
    push(stamp() .. " [event] " .. event .. " " .. table.concat(parts, ", "))
end

-- Every error is kept, counted by message, up to ERRORS_MAX distinct ones. The player sees one chat line per
-- session, and the game's own error handler gets it too, so BugSack catches it.
function Debug.Error(err, stack)
    local msg = tostring(err)
    local d = dev()
    if d then
        local key = msg
        local e = d.errors[key]
        if not e then
            local distinct = 0
            for _ in pairs(d.errors) do
                distinct = distinct + 1
            end
            if distinct >= ERRORS_MAX then
                key = OTHER_ERRORS
                e = d.errors[key]
            end
        end
        if not e then
            e = { count = 0, first = date("%Y-%m-%d %H:%M:%S"), stack = stack, version = ns.VERSION }
            d.errors[key] = e
        end
        e.count = e.count + 1
        e.last = date("%Y-%m-%d %H:%M:%S")
        if d.debug then
            push(stamp() .. " [error] " .. msg)
        end
    end
    if not reportedThisSession then
        reportedThisSession = true
        print("|cffff5555" .. ns.TITLE .. " :|r " .. (ns.L and ns.L.ERROR_LINE or "error, /kq errors"))
    end
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        pcall(handler, msg .. "\n" .. tostring(stack))
    end
end

-- The latest first, then the most frequent. Dates sort as text, being year first.
function Debug.ErrorsText()
    local d = dev()
    local list = {}
    for msg, e in pairs(d and d.errors or {}) do
        if type(e) == "table" then
            list[#list + 1] = { msg = tostring(msg), e = e, last = tostring(e.last or ""), count = tonumber(e.count) or 0 }
        end
    end
    table.sort(list, function(a, b)
        if a.last ~= b.last then
            return a.last > b.last
        elseif a.count ~= b.count then
            return a.count > b.count
        end
        return a.msg < b.msg
    end)
    local lines = {}
    for i, x in ipairs(list) do
        local e = x.e
        lines[i] = string.format("x%d  first %s  last %s  v%s\n%s\n%s\n", x.count, tostring(e.first), tostring(e.last or "?"),
            tostring(e.version or "?"), x.msg, tostring(e.stack or ""))
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end

function Debug.LogText()
    local d = dev()
    return d and #d.log > 0 and table.concat(d.log, "\n") or "(empty)"
end

function Debug.Clear()
    local d = dev()
    d.log = {}
    d.errors = {}
end

-- One line per key, sorted, nested tables indented. For dumps.
local function serialize(value, indent, lines, seen)
    indent = indent or ""
    lines = lines or {}
    seen = seen or {}
    if type(value) ~= "table" then
        lines[#lines + 1] = indent .. tostring(value)
        return lines
    end
    if seen[value] then
        lines[#lines + 1] = indent .. "(seen)"
        return lines
    end
    seen[value] = true
    local keys = {}
    for k in pairs(value) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for _, k in ipairs(keys) do
        local v = value[k]
        if type(v) == "table" then
            lines[#lines + 1] = indent .. tostring(k) .. ":"
            serialize(v, indent .. "    ", lines, seen)
        else
            lines[#lines + 1] = indent .. tostring(k) .. " = " .. (type(v) == "string" and string.format("%q", v) or tostring(v))
        end
    end
    return lines
end
ns.Serialize = serialize

-- Blizzard's red X, raised above the window's own parts, such as a template's border at level 500.
function ns.CloseButton(window, x, y)
    local close = CreateFrame("Button", nil, nil, "UIPanelCloseButton")
    close:SetParent(window)
    local top = window:GetFrameLevel()
    for _, part in ipairs({ window:GetChildren() }) do
        if part ~= close then
            top = math.max(top, part:GetFrameLevel())
        end
    end
    close:SetFrameLevel(top + 1)
    close:SetPoint("TOPRIGHT", x, y)
    return close
end

-- A window to read and copy text: Ctrl+A, then Ctrl+C. Built on first use.
local window
local function buildWindow()
    local f = CreateFrame("Frame", "KaLiQuestTextWindow", nil, "BackdropTemplate")
    f:SetParent(UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetSize(720, 520)
    f:SetPoint("CENTER")
    f:SetBackdrop(BACKDROP_DARK_DIALOG_32_32)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "KaLiQuestTextWindow")

    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Title:SetPoint("TOPLEFT", 18, -16)

    ns.CloseButton(f, -6, -6)

    local scroll = CreateFrame("ScrollFrame", nil, nil, "UIPanelScrollFrameTemplate")
    scroll:SetParent(f)
    scroll:SetPoint("TOPLEFT", 18, -40)
    scroll:SetPoint("BOTTOMRIGHT", -36, 18)

    local edit = CreateFrame("EditBox", nil, nil)
    edit:SetParent(scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(650)
    edit:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    scroll:SetScrollChild(edit)
    f.Edit = edit
    return f
end

function Debug.ShowText(title, text)
    window = window or buildWindow()
    window.Title:SetText(ns.TITLE .. " — " .. title)
    window.Edit:SetText(text)
    window.Edit:HighlightText()
    window:Show()
    window.Edit:SetFocus()
end
