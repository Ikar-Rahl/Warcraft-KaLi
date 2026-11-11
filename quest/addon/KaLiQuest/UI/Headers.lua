-- The tracker's headers: the title row and its tools, the category bars, the groups, and naming a group in place.
local _, ns = ...
local L = ns.L
local Tracker = ns.Tracker
local Shared = Tracker.Shared
local layout, COLOR, HEADER = Shared.layout, Shared.COLOR, Shared.HEADER
local guarded, paint, newFrame = Shared.guarded, Shared.paint, Shared.newFrame

local Headers = {}
ns.Headers = Headers

local GROUP_MIN_HEIGHT = 15
local TITLE_TOOLS_WIDTH = 104

-- Renaming in place ------------------------------------------------------------------------------------------

local renaming -- the ID of the group being named in place
local renameAttached = false
local renameBox

function Headers.FinishRename(save)
    local id = renaming
    if not id then
        return
    end
    renaming = nil
    if save then
        local ok, reason = ns.model:RenameGroup(id, renameBox:GetText())
        if not ok and reason ~= "empty" and reason ~= "missing" then
            Shared.refuse(reason)
        end
    end
    renameBox:ClearFocus()
    renameBox:Hide()
    ns.RequestRefresh()
end
local finishRename = Headers.FinishRename

function Headers.StartRename(groupID)
    if renaming then
        finishRename(true)
    end
    renaming = groupID
    Tracker.Refresh()
end

function Headers.Renaming()
    return renaming
end

-- A layout attaches the box to its group's header; a group no longer drawn saves the name typed so far.
function Headers.BeginDraw()
    renameAttached = false
end
function Headers.EndDraw()
    if renaming and not renameAttached then
        finishRename(true)
    end
end

function Headers.BuildRenameBox(parent)
    local box = newFrame("EditBox", parent)
    box:SetAutoFocus(false)
    box:SetFontObject("KaLiQuestLineFont")
    box:SetTextColor(1, 1, 1)
    box:SetMaxLetters(ns.Model.NAME_MAX)
    box:SetHeight(16)
    box:SetTextInsets(3, 3, 0, 0)
    box.Bg = box:CreateTexture(nil, "BACKGROUND")
    box.Bg:SetAllPoints()
    box.Bg:SetColorTexture(0, 0, 0, 0.7)
    box:SetScript("OnEnterPressed", guarded(function()
        finishRename(true)
    end))
    box:SetScript("OnEscapePressed", guarded(function()
        finishRename(false)
    end))
    box:SetScript("OnEditFocusLost", guarded(function()
        finishRename(true)
    end))
    box:Hide()
    renameBox = box
    return box
end

-- Bars -------------------------------------------------------------------------------------------------------

local function onBarClick(self, button)
    if ns.Drag.JustDragged() then
        return
    end
    local line = self.line
    if button == "RightButton" then
        ns.Menus.Bar(self, line)
        return
    end
    if Shared.refusedByLock() then
        return
    end
    local open = ns.db.open.categories
    if line.id == "journal" then
        -- Journal starts open, so its closed state is kept as false rather than left out.
        open.journal = not open.journal
    elseif line.extra then
        -- Recipes and achievements are open until closed, so only closed is kept, as false.
        open[line.id] = open[line.id] == false
    else
        open[line.id] = not open[line.id] or nil
    end
    Shared.playToggle()
    ns.RequestRefresh()
end

local function colourBar(bar)
    local top = bar.line and bar.line.top
    paint(bar.Text, bar.hover and COLOR.white or (top and HEADER.gold or HEADER.subbar))
end

function Headers.NewBar()
    local b = newFrame("Button", Tracker.frames.content)
    b:SetHeight(Shared.BAR_HEIGHT)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.Art = b:CreateTexture(nil, "BACKGROUND")
    b.Art:SetAtlas("ui-questtracker-secondary-objective-header", false)
    b.Art:SetPoint("CENTER")
    -- The padding keeps the tail of the font's J inside the bar's clipping.
    b.Text = b:CreateFontString(nil, "ARTWORK", "KaLiQuestHeaderFont")
    b.Text:SetPoint("LEFT", 7, 0)
    b.Text:SetJustifyH("LEFT")
    b.Text:SetWordWrap(false)
    b.Count = b:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    b.Count:SetPoint("RIGHT", -20, 0)
    b.Here = b:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    paint(b.Here, COLOR.white)
    b.Arrow = Shared.arrow(b)
    b.Add = Shared.iconButton(b, "ui-questtrackerbutton-secondary-expand", 18, 14, 0.8, L.NEW_GROUP)
    -- One stray click would move every row below it, so the + also waits for the padlock.
    b.Add:SetScript("OnClick", guarded(function()
        if InCombatLockdown() then
            Shared.refuse("combat")
        elseif not Shared.refusedByLock() then
            ns.Menus.NewGroup()
        end
    end))
    b:SetScript("OnClick", guarded(onBarClick))
    b:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        self.hover = true
        colourBar(self)
    end))
    b:SetScript("OnLeave", guarded(function(self)
        self.hover = false
        colourBar(self)
    end))
    ns.Motion.AddFlash(b, b.Art)
    ns.Drag.Register(b, "bar")
    return b
end

-- How many quests under a header are in their area, as the bench draws it: the arrow, then the number.
local function drawHere(fs, line, size)
    local n = ns.Area.Count(line.quests)
    fs:SetShown(n > 0)
    if n > 0 then
        fs:SetText(string.format(Shared.AREA_ARROW, math.floor(size * 0.83 + 0.5), math.floor(size * 0.67 + 0.5)) .. n)
    end
    return n > 0 and fs:GetStringWidth() or 0
end

local barsBefore -- the bars of the last layout, so one that's new fades in, as Blizzard's headers do

function Headers.SetBarsSeen(bars)
    barsBefore = bars
end

function Headers.DrawBar(b, line)
    local width = layout.width
    b.line = line
    b:SetWidth(width)
    b.Art:SetSize(width + 40, 30)
    b.Art:SetAlpha(line.top and 1 or 0.45)
    local grey = 1 - layout.saturation
    b.Art:SetDesaturation(grey)
    b.Arrow:SetDesaturation(grey)
    b.Add.Icon:SetDesaturation(grey)
    paint(b.Count, HEADER.barCount)
    b.Text:SetText(ns.CategoryName(line.id))
    b.Count:SetText(line.count)
    Shared.setArrow(b.Arrow, line.open)
    if barsBefore and not barsBefore[line.id] then
        b.FadeIn:Stop()
        b.FadeIn:Play()
    end
    local right = 20 + b.Count:GetStringWidth()
    local hereWidth = drawHere(b.Here, line, ns.Fonts.Size())
    if hereWidth > 0 then
        b.Here:ClearAllPoints()
        b.Here:SetPoint("RIGHT", b, "RIGHT", -(right + 4), 0)
        right = right + 4 + hereWidth
    end
    if line.id == "mine" then
        b.Add:ClearAllPoints()
        b.Add:SetPoint("RIGHT", b, "RIGHT", -(right + 6), 0)
        b.Add:Show()
        b.Add:EnableMouse(not Shared.EditMode())
        right = right + 6 + 18
    else
        b.Add:Hide()
    end
    if line.extra then
        right = right + ns.Sections.Adopt(b, line.id, right)
    end
    b.Text:SetWidth(width - 7 - right - 6)
    colourBar(b)
end

-- Groups -----------------------------------------------------------------------------------------------------

local function onGroupClick(self, button)
    if ns.Drag.JustDragged() then
        return
    end
    local line = self.line
    if button == "RightButton" then
        ns.Menus.Group(self, line)
        return
    end
    if Shared.refusedByLock() then
        return
    end
    ns.Menus.SetGroupOpen(line, not line.open)
    Shared.playToggle()
    ns.RequestRefresh()
end

local function colourGroup(g)
    paint(g.Name, g.hover and COLOR.groupHover or COLOR.group)
    g.Arrow:SetAlpha(g.hover and 1 or 0.7)
end

function Headers.NewGroup()
    local g = newFrame("Button", Tracker.frames.content)
    g:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    g.Name = g:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    g.Name:SetJustifyH("LEFT")
    g.Name:SetMaxLines(2)
    g.Count = g:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    g.Count:SetJustifyH("RIGHT")
    g.Count:SetPoint("RIGHT", -20, 0)
    paint(g.Count, COLOR.count)
    g.Here = g:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    paint(g.Here, COLOR.white)
    g.Arrow = Shared.arrow(g)
    g.Eye = Shared.iconButton(g, "gm-icon-visible", 16, 16, 0.65, L.CLOSE_OTHERS)
    g.Eye:SetScript("OnClick", guarded(function(self)
        ns.Menus.FocusGroup(self:GetParent().line)
    end))
    g:SetScript("OnClick", guarded(onGroupClick))
    g:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        self.hover = true
        colourGroup(self)
    end))
    g:SetScript("OnLeave", guarded(function(self)
        self.hover = false
        colourGroup(self)
    end))
    ns.Motion.AddFlash(g)
    ns.Drag.Register(g, "group")
    return g
end

function Headers.DrawGroup(g, line, size)
    local width = layout.width - layout.groupIndent
    local editMode = Shared.EditMode()
    g.line = line
    g:SetWidth(width)
    g.Count:SetText(line.count)
    Shared.setArrow(g.Arrow, line.open)
    local countBox = math.max(g.Count:GetStringWidth(), math.ceil(size * 2.2))
    g.Eye:ClearAllPoints()
    g.Eye:SetPoint("RIGHT", g, "RIGHT", -(20 + countBox + 5), 0)
    g.Eye:EnableMouse(not editMode)
    local hereWidth = drawHere(g.Here, line, size)
    if hereWidth > 0 then
        g.Here:ClearAllPoints()
        g.Here:SetPoint("RIGHT", g.Eye, "LEFT", -3, 0)
        hereWidth = hereWidth + 3
    end
    local nameWidth = width - 9 - (20 + countBox + 5 + 16 + 5) - hereWidth
    g.Name:SetWidth(nameWidth)
    g.Name:SetText(line.name)
    local height = math.max(GROUP_MIN_HEIGHT, g.Name:GetStringHeight())
    g:SetHeight(height)
    g.Name:ClearAllPoints()
    g.Name:SetPoint("LEFT", 9, 0)
    colourGroup(g)
    if line.group and line.group.id == renaming then
        renameAttached = true
        g.Name:Hide()
        renameBox:SetParent(g)
        renameBox:ClearAllPoints()
        renameBox:SetPoint("LEFT", g, "LEFT", 6, 0)
        renameBox:SetWidth(nameWidth + 3)
        if not renameBox:IsShown() then
            renameBox:SetText(line.name)
            renameBox:Show()
            renameBox:SetFocus()
            renameBox:HighlightText()
        end
    else
        g.Name:Show()
    end
end

-- The title row ----------------------------------------------------------------------------------------------

-- The quest log's own settings button, questlog-icon-setting at 15 by 16. The game has no bright gear, so a second
-- copy is added on top, as the template's highlight does; in combat it's greyed, without the copy.
local function buildGear(parent)
    local b = newFrame("Button", parent)
    b:SetSize(18, 18)
    b:SetPoint("RIGHT", -83, 0)
    b:RegisterForClicks("LeftButtonUp")
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAtlas("questlog-icon-setting", false)
    b.Icon:SetSize(15, 16)
    b.Icon:SetPoint("TOPLEFT", 1, -1)
    b.Bright = b:CreateTexture(nil, "OVERLAY")
    b.Bright:SetAtlas("questlog-icon-setting", false)
    b.Bright:SetSize(15, 16)
    b.Bright:SetPoint("TOPLEFT", 1, -1)
    b.Bright:SetBlendMode("ADD")
    b:SetScript("OnClick", guarded(function(self)
        ns.Menus.Gear(self)
    end))
    b:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        Shared.simpleTip(self, L.OPTIONS)
        if InCombatLockdown() then
            GameTooltip:AddLine(ns.G("ERR_NOT_IN_COMBAT", "In combat"), 1, 0.1, 0.1)
            GameTooltip:Show()
        end
    end))
    b:SetScript("OnLeave", guarded(Shared.hideTip))
    return b
end

local function drawGear(b)
    local fight = InCombatLockdown()
    b.Icon:SetDesaturated(fight)
    b.Bright:SetShown(not fight)
    b:SetAlpha(fight and 0.45 or 1)
    b:EnableMouse(not Shared.EditMode())
end

function Headers.BuildTitle(root)
    local t = newFrame("Frame", root)
    t:SetSize(layout.width, Shared.TITLE_HEIGHT)
    t.Art = t:CreateTexture(nil, "BACKGROUND")
    t.Art:SetAtlas("ui-questtracker-primary-objective-header", false)
    t.Art:SetPoint("CENTER")
    t.Text = t:CreateFontString(nil, "ARTWORK", "KaLiQuestHeaderFont")
    t.Text:SetPoint("LEFT", 7, 0)
    t.Text:SetJustifyH("LEFT")
    t.Text:SetWordWrap(false)
    t.Text:SetText(ns.G("TRACKER_ALL_OBJECTIVES", "Tous les objectifs"))
    -- Hover only, so clicks still reach the world behind the title.
    t:SetMouseMotionEnabled(true)
    t:SetScript("OnEnter", guarded(Shared.wake))
    -- Right to left: collapse-all, filter, search, padlock, gear, as on the bench.
    t.Tools = newFrame("Frame", t)
    t.Tools:SetAllPoints()
    t.Tools:SetAlpha(Shared.TOOLS_REST_ALPHA)
    -- Collapse-all is the bars' double arrow, Ikar's ruling on 2026-11-07, rather than Blizzard's red button.
    t.Min = newFrame("Button", t.Tools)
    t.Min:SetSize(18, 19)
    t.Min:SetPoint("RIGHT", -1, 0)
    t.Min.Arrow = Shared.arrow(t.Min)
    t.Min.Arrow:ClearAllPoints()
    t.Min.Arrow:SetPoint("CENTER")
    -- Hover adds a copy on top, as Blizzard's highlights do, since a colour above 1 doesn't brighten.
    t.Min.Bright = t.Min:CreateTexture(nil, "HIGHLIGHT")
    t.Min.Bright:SetAtlas("covenantsanctum-renown-doublearrow", false)
    t.Min.Bright:SetSize(9, 12)
    t.Min.Bright:SetPoint("CENTER")
    t.Min.Bright:SetBlendMode("ADD")
    t.Min.Bright:SetAlpha(0.3)
    t.Min:SetScript("OnClick", guarded(ns.Lock.ToggleAll))
    t.Min:SetScript("OnEnter", guarded(Shared.wake))
    t.Filter, t.Search = ns.Search.BuildButtons(t.Tools)
    t.Lock = ns.Lock.Build(t.Tools)
    t.Gear = buildGear(t.Tools)
    return t
end

function Headers.DrawTitle(t, root, top)
    local width, grey = layout.width, 1 - layout.saturation
    local open = ns.db.open.tracker
    local editMode = Shared.EditMode()
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -top)
    t:SetWidth(width)
    t.Art:SetSize(width + 40, 40)
    t.Art:SetDesaturation(grey)
    paint(t.Text, HEADER.gold)
    t.Text:SetWidth(width - 7 - TITLE_TOOLS_WIDTH - 6)
    Shared.setArrow(t.Min.Arrow, open)
    Shared.setArrow(t.Min.Bright, open)
    t.Min.Arrow:SetDesaturation(grey)
    t.Min.Bright:SetDesaturation(grey)
    t.Min:EnableMouse(not editMode)
    t:SetMouseMotionEnabled(not editMode)
    ns.Lock.Draw(t.Lock)
    drawGear(t.Gear)
    ns.Search.DrawButtons()
end
