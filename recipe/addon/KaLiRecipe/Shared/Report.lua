-- Copied from shared/addon/Report.lua by tools/sync_shared.py: edit the source, not this copy.
-- The bug report, shared by the KaLi addons: what the addon sees, as plain text, and the window that hands it over.
-- An addon reaches neither the clipboard nor the web, so the button selects the text for Ctrl+C and the player pastes
-- it at the address shown. No character or realm name goes in it.
--
-- The addon's UI/Report.lua sets Report.URL (where reports are posted, or nil), Report.StatusLines (more lines for
-- the status, after Commands.StatusText()) and Report.Sections ({ name, fn } in order, between the game's warnings and
-- the list of addons). Opened with Report.Open().
local _, ns = ...
local L = ns.L

local Report = {}
ns.Report = Report

Report.URL = nil
Report.Sections = {}

-- GitHub takes 65,536 characters in an issue.
local MAX_CHARS = 60000
local LOG_LINES = 100

local function plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

local function dev()
    local d = ns.DevDB()
    return type(d) == "table" and d or {}
end

function Report.NoData()
    return "(no saved data: " .. tostring(ns.disabled) .. ")"
end

-- The names in list a that list b lacks.
local function without(a, b)
    local inB, out = {}, {}
    for _, name in ipairs(b or {}) do
        inB[name] = true
    end
    for _, name in ipairs(a or {}) do
        if not inB[name] then
            out[#out + 1] = name
        end
    end
    return out
end

local function statusText()
    local lines = { ns.Commands.StatusText() }
    if Report.StatusLines then
        lines[#lines + 1] = Report.StatusLines()
    end
    return table.concat(lines, "\n")
end

local function apiText()
    local r = ns.SelfCheck.Run()
    local lines = { string.format("checked %d, missing %d, not loaded so not checked %d", r.checked, #r.missing, r.skipped) }
    for _, m in ipairs(r.missing) do
        lines[#lines + 1] = "  missing: " .. m
    end
    lines[#lines + 1] = string.format("assumptions: %d tried, %d things not as the addon assumes", #r.assumed, r.failing)
    for _, a in ipairs(r.assumed) do
        lines[#lines + 1] = string.format("  %s: looked at %d%s", a.name, a.looked, a.note and (", " .. a.note) or "")
        for _, w in ipairs(a.wrong) do
            lines[#lines + 1] = "    not as assumed: " .. w
        end
    end
    local history = dev().apiChecks
    history = type(history) == "table" and history or {}
    for _, e in ipairs(history) do
        lines[#lines + 1] = string.format("  at login, build %s, %s, %s: %d missing, %d not as assumed", tostring(e.build),
            tostring(e.version), tostring(e.when), #(e.missing or {}), e.failing or 0)
    end
    -- What a patch broke: the difference with the last other build seen.
    local _, build = GetBuildInfo()
    for i = #history, 1, -1 do
        local e = history[i]
        if e.build ~= build then
            local gone, back = without(r.missing, e.missing), without(e.missing, r.missing)
            lines[#lines + 1] = string.format("  since build %s: newly missing %s; back %s", tostring(e.build),
                #gone > 0 and table.concat(gone, ", ") or "none", #back > 0 and table.concat(back, ", ") or "none")
            break
        end
    end
    return table.concat(lines, "\n")
end

-- What the player changed.
function Report.OptionsText()
    if not ns.db then
        return Report.NoData()
    end
    local lines = ns.Serialize(ns.db.options)
    return #lines > 0 and table.concat(lines, "\n") or "(all at their defaults)"
end

local function addonsText()
    local names = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then
            names[#names + 1] = name .. " " .. tostring(C_AddOns.GetAddOnMetadata(name, "Version") or "?")
        end
    end
    return #names .. " loaded: " .. table.concat(names, ", ")
end

local function testsText()
    local t = dev().lastTests
    if type(t) ~= "table" then
        return "(never run in game)"
    end
    return string.format("%s, %s: %s", tostring(t.when), tostring(t.version), tostring(t.summary))
end

local function logText()
    local d = dev()
    local log = type(d.log) == "table" and d.log or {}
    local lines = { "debug mode " .. (d.debug and "on" or "off") .. ", " .. #log .. " lines" }
    for i = math.max(1, #log - LOG_LINES + 1), #log do
        lines[#lines + 1] = log[i]
    end
    return table.concat(lines, "\n")
end

-- The most telling first, as a report too long loses its end.
local function sections()
    local list = {
        { "status", statusText },
        { "api check", apiText },
        { "errors", function()
            return ns.Debug.ErrorsText()
        end },
        { "game warnings", function()
            return ns.SelfCheck.WarningsText()
        end },
    }
    for _, s in ipairs(Report.Sections) do
        list[#list + 1] = s
    end
    list[#list + 1] = { "addons", addonsText }
    list[#list + 1] = { "tests", testsText }
    list[#list + 1] = { "log", logText }
    return list
end

-- Each part is made apart, so one that fails leaves the others.
function Report.Text()
    local out = { string.format("%s bug report, %s", ns.TITLE, date("%Y-%m-%d %H:%M:%S")), "" }
    for _, s in ipairs(sections()) do
        local ok, text = pcall(s[2])
        out[#out + 1] = "== " .. s[1] .. " =="
        out[#out + 1] = plain(ok and text or "(failed: " .. tostring(text) .. ")")
        out[#out + 1] = ""
    end
    local text = table.concat(out, "\n")
    if #text > MAX_CHARS then
        text = (text:sub(1, MAX_CHARS):match("^(.*)\n") or "") .. "\n(cut at " .. MAX_CHARS .. " characters)"
    end
    return text
end

local frame
local current = ""

-- What the player types is undone, so the text stays whole for Ctrl+C.
local function readOnly(edit, text)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(text())
            self:HighlightText()
        end
    end)
end

local function fill()
    current = Report.Text()
    frame.Box:SetText(current)
    frame.Box:SetCursorPosition(0)
    frame.Hint:SetText("")
    frame.URL:SetShown(Report.URL ~= nil)
    frame.NoURL:SetShown(Report.URL == nil)
    if Report.URL then
        frame.URL:SetText(Report.URL)
        frame.URL:SetCursorPosition(0)
    end
end

local function build()
    local function child(kind, template)
        local f = CreateFrame(kind, nil, nil, template)
        f:SetParent(frame)
        return f
    end
    local name = ns.ADDON .. "Report"
    frame = CreateFrame("Frame", name, nil, "DefaultPanelFlatTemplate")
    frame:SetParent(UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(560, 480)
    frame:SetPoint("CENTER")
    frame:SetTitle(L.REPORT_TITLE)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, name)

    -- Where Forever's own close button sits on this panel.
    ns.CloseButton(frame, 0, 3):SetSize(28, 28)

    local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 20, -34)
    intro:SetPoint("TOPRIGHT", -20, -34)
    intro:SetJustifyH("LEFT")
    intro:SetText(L.REPORT_INTRO)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
    label:SetText(L.REPORT_ADDRESS)
    frame.URL = child("EditBox", "InputBoxTemplate")
    frame.URL:SetAutoFocus(false)
    frame.URL:SetSize(400, 20)
    frame.URL:SetPoint("LEFT", label, "RIGHT", 14, 0)
    readOnly(frame.URL, function()
        return Report.URL or ""
    end)
    frame.NoURL = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.NoURL:SetPoint("LEFT", label, "RIGHT", 8, 0)
    frame.NoURL:SetText(L.REPORT_NO_ADDRESS)

    frame.Copy = child("Button", "UIPanelButtonTemplate")
    frame.Copy:SetSize(200, 24)
    frame.Copy:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -14)
    frame.Copy:SetText(L.REPORT_COPY)
    frame.Copy:SetScript("OnClick", function()
        ns.SafeCall(Report.Select)
    end)
    frame.Hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.Hint:SetPoint("LEFT", frame.Copy, "RIGHT", 12, 0)

    local scroll = child("ScrollFrame", "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame.Copy, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    frame.Box = CreateFrame("EditBox", nil, nil)
    frame.Box:SetParent(scroll)
    frame.Box:SetMultiLine(true)
    frame.Box:SetAutoFocus(false)
    frame.Box:SetFontObject(ChatFontNormal)
    frame.Box:SetWidth(484)
    scroll:SetScrollChild(frame.Box)
    readOnly(frame.Box, function()
        return current
    end)
    frame.Box:SetScript("OnEscapePressed", frame.Box.ClearFocus)
    -- The game copies on the key itself, so the box lets go of the keyboard just after.
    frame.Box:SetScript("OnKeyDown", function(_, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown and IsMetaKeyDown()) then
            C_Timer.After(0, function()
                frame.Box:ClearFocus()
                frame.Hint:SetText(L.REPORT_COPIED)
            end)
        end
    end)

    frame:SetScript("OnShow", function()
        ns.SafeCall(fill)
    end)
    frame:Hide()
end

-- The button: the report made again, selected, for Ctrl+C.
function Report.Select()
    fill()
    frame.Box:SetFocus()
    frame.Box:HighlightText()
    frame.Hint:SetText(L.REPORT_PRESS_COPY)
end

function Report.Open()
    if not frame then
        build()
    end
    if frame:IsShown() then
        fill()
    else
        frame:Show()
    end
    frame:Raise()
end

-- For the offline smoke test.
function Report.Frame()
    return frame
end
