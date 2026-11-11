-- Quest rows, the grey lines moved quests leave, and tracked recipes' and achievements' entries: their frames, what
-- they show and how they're laid out. Item buttons, motion and dragging hook in from their own files.
local _, ns = ...
local L = ns.L
local Tracker = ns.Tracker
local Shared = Tracker.Shared
local layout, COLOR = Shared.layout, Shared.COLOR
local guarded, paint, newFrame = Shared.guarded, Shared.paint, Shared.newFrame

local Rows = {}
ns.Rows = Rows

local LINE_GAP = 4
local POI_ROOM = 24 -- with map buttons, the level sits this much further left
local FREQUENCY = ns.Filter.FREQUENCY
local picked = {} -- quests picked with Ctrl+click, until a click without it. Not saved
local pickOrder = {} -- the quest rows of the last layout, top to bottom
local hovered -- the quest row or moved line under the pointer
local retip

-- Clicks, colours and tooltips --------------------------------------------------------------------------------

local function onRowClick(self, button)
    if ns.Drag.JustDragged() then
        return
    end
    local q = self.line and self.line.quest
    if not q or q.leaving then
        return
    end
    if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID and ChatFrameUtil.TryInsertQuestLinkForQuestID(q.id) then
        return
    end
    if button == "RightButton" then
        local ids = picked[q.id] and Rows.Picked() or {}
        if #ids > 1 then
            ns.Menus.Picked(self, ids)
        else
            ns.Menus.Quest(self, q)
        end
        return
    end
    -- Ctrl+click picks or unpicks a quest's row. It moves nothing, so combat and the padlock allow it.
    if IsControlKeyDown() and self.line.kind == "quest" then
        Rows.TogglePick(q.id)
        if hovered == self then
            retip(self)
        end
        return
    end
    Rows.ClearPicked()
    if IsModifiedClick("QUESTWATCHTOGGLE") then
        ns.Menus.ToggleTracking(q.id)
        -- The quest leaves from under the pointer, so its hint goes.
        Shared.hideTip(self)
    else
        ns.Menus.OpenDetails(q)
    end
end

local function colourRow(row)
    local lit = row.hover or row.selected or row.picked
    -- In the quest's area, title and objectives take the hover's colours.
    local bright = row.hover or row.area
    paint(row.Title, bright and COLOR.white or COLOR.title)
    for i = 1, row.shownLines or 0 do
        local l = row.lines[i]
        local style = l.style
        local c
        if style == "complete" then
            c = COLOR.complete
        elseif style == "failed" then
            c = row.hover and COLOR.failedHover or COLOR.failed
        else
            c = bright and COLOR.white or COLOR.normal
        end
        paint(l.Text, c)
        paint(l.Dash, row.hover and COLOR.white or COLOR.normal)
    end
    row.Bg:SetAlpha(lit and layout.blockHover or (InCombatLockdown() and layout.blockCombat or layout.blockRest))
end

-- What a click would do with the modifiers held now, in the order onRowClick tries them, and whether the game
-- refuses it now.
local function clickHint(row, q)
    if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow() then
        return L.HINT_LINK
    elseif IsControlKeyDown() and row.line.kind == "quest" then
        return picked[q.id] and L.UNPICK or L.HINT_PICK
    elseif IsModifiedClick("QUESTWATCHTOGGLE") then
        local text = ns.model:GroupOf(q.id) and ns.G("OBJECTIVES_STOP_TRACKING", "Arrêter le suivi") or L.HINT_TRACK
        return text, InCombatLockdown()
    end
end

-- No tooltip at rest, neither party progress nor markers' names, Ikar's rulings on 2026-11-10; Blizzard's event
-- still lets other addons add their own. Before the first group exists, one line says how to make one. A moved
-- quest's line names its group. Holding Shift or Ctrl shows what a click would then do in one plain word, in its own
-- small box (Shared.showHint).
local function rowTooltip(row)
    local line = row.line
    local q = line and line.quest
    if not q or q.leaving then
        return
    end
    local shown = false
    local function own()
        local gap = (row.gutter or 0) * row:GetEffectiveScale() / GameTooltip:GetEffectiveScale()
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPRIGHT", row, "TOPLEFT", -gap, 0)
        GameTooltip:SetOwner(row, "ANCHOR_PRESERVE")
        shown = true
    end
    if line.kind == "moved" then
        local g = ns.model:GroupOf(q.id)
        if not g then
            return
        end
        own()
        GameTooltip:SetText(string.format(L.IN_GROUP, g.name), 1, 1, 1)
    else
        -- A tooltip's first line takes the header font, so the line goes under the quest's title.
        if #ns.db.groups == 0 then
            own()
            GameTooltip:SetText(q.title, 1, 1, 1)
            GameTooltip:AddLine(L.FIRST_GROUP_HINT, 0.1, 1, 0.1)
        end
        -- The last value says whether a tooltip is already up: other addons add to it, or open their own.
        if EventRegistry and EventRegistry.TriggerEvent then
            EventRegistry:TriggerEvent("OnQuestBlockHeader.OnEnter", row, q.id, shown)
        end
    end
    if shown then
        GameTooltip:Show()
    end
    local hint, refused = clickHint(row, q)
    if hint then
        Shared.showHint(row, hint, refused, row.gutter or 0)
    end
end

retip = function(row)
    Shared.hideTip(row)
    rowTooltip(row)
end

-- Pressing or letting go of Shift or Ctrl over a quest redraws its tooltip with what a click would now do.
ns.On("MODIFIER_STATE_CHANGED", function()
    if hovered and hovered:IsVisible() then
        retip(hovered)
    end
end)

-- The row's box as its hit rect, badge and map button included.
local function overBox(row)
    return row:IsMouseOver(3, -3, -(row.gutter or 0), 2)
end

-- Leaving through the eye, the item or the map button never reaches the row, so the button checks for itself.
local function watchPointer(self)
    local row = self:GetParent()
    if not (row.hover or overBox(row)) then
        self:Hide()
    end
end

-- With "only on hover", the share button shows while the pointer is on its row's box.
local function showShare(row)
    local onHover = ns.db.options.shareOnHover
    row.Share:SetShown(row.canShare == true and (not onHover or row.hover or overBox(row)))
    row.Share:SetScript("OnUpdate", onHover and watchPointer or nil)
end

-- Frames -----------------------------------------------------------------------------------------------------

function Rows.NewRow()
    local row = newFrame("Button", Tracker.frames.content)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.Bg = row:CreateTexture(nil, "BACKGROUND")
    row.Bg:SetColorTexture(0, 0, 0, 1)
    row.SepTop = Shared.separator(row)
    row.SepBottom = Shared.separator(row)
    -- Picked: the box washed gold with a gold left edge, as drop targets are lit.
    row.Picked = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.Picked:SetColorTexture(1, 0.824, 0, 0.1)
    row.PickedEdge = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.PickedEdge:SetColorTexture(1, 0.824, 0, 0.55)
    row.PickedEdge:SetWidth(2)
    -- Forever's own nameplate level art, stretched to the text as the nameplates stretch it: Ikar's pick on 2026-11-08.
    row.Badge = row:CreateTexture(nil, "BORDER")
    row.Badge:SetAtlas("ui-hud-nameplates-levelindicator", false)
    row.Level = row:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    row.Level:SetPoint("CENTER", row.Badge, "CENTER", 0, 0)
    row.Title = row:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    row.Title:SetJustifyH("LEFT")
    row.Title:SetMaxLines(2)
    row.Title:SetPoint("TOPLEFT", 0, 0)
    -- Addons that find quest titles by their text, as Forever Quest Tint does, find this hidden copy holding the bare
    -- title, mark it, and the row shows what they made of it, before its markers. Its holder takes the height and
    -- logo they give the "block", so the row's own layout stays the addon's.
    row.TitleHolder = newFrame("Frame", row)
    row.TitleHolder.kaliQuestOwn = true
    row.TitleHolder:SetPoint("TOPLEFT", 0, 0)
    row.TitleSource = row.TitleHolder:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    row.TitleSource:SetPoint("TOPLEFT", 0, 0)
    row.TitleSource:Hide()
    -- Marked later, outside a layout, the copy changes: redraw to show it.
    hooksecurefunc(row.TitleSource, "SetText", function()
        if not row.settingTitle then
            ns.RequestRefresh()
        end
    end)
    row.lines = {}
    -- Blizzard's map button and find-group button. Both are the row's own, so the room for other addons' buttons
    -- doesn't count them.
    local templates = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    if templates and templates("ObjectiveTrackerPOIButtonTemplate") then
        row.POI = newFrame("Button", row, "ObjectiveTrackerPOIButtonTemplate")
        row.POI.kaliQuestOwn = true
    end
    if templates and templates("QuestObjectiveFindGroupButtonTemplate") then
        row.Eye = newFrame("Button", row, "QuestObjectiveFindGroupButtonTemplate")
        row.Eye.kaliQuestOwn = true
        row.Eye:Hide()
    end
    -- Where the item's secure button sits. In combat, if no button is lined up with it, the icon shows grey here.
    row.ItemSlot = row:CreateTexture(nil, "ARTWORK")
    row.ItemSlot:SetSize(26, 26)
    row.ItemSlot:SetDesaturated(true)
    row.ItemSlot:SetVertexColor(0.55, 0.55, 0.55)
    row.ItemSlot:Hide()
    -- The quick share button. Blizzard has none, so the quest log's share frame holds the group icon.
    row.Share = newFrame("Button", row)
    row.Share.kaliQuestOwn = true
    row.Share:SetSize(22, 22)
    row.Share:SetNormalAtlas("questsharing-questlog-button")
    row.Share:SetPushedAtlas("questsharing-questlog-buttonpressed")
    row.Share:SetHighlightAtlas("questsharing-questlog-buttonhighlight", "ADD")
    row.Share.Icon = row.Share:CreateTexture(nil, "OVERLAY")
    row.Share.Icon:SetAtlas("socialqueuing-icon-group", false)
    row.Share.Icon:SetSize(15, 13)
    row.Share.Icon:SetPoint("CENTER")
    row.Share:SetScript("OnClick", guarded(function(self)
        local q = self:GetParent().line and self:GetParent().line.quest
        if q and QuestUtil and QuestUtil.ShareQuest then
            QuestUtil.ShareQuest(q.id)
        end
    end))
    row.Share:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        Shared.simpleTip(self, ns.G("SHARE_QUEST", "Partage de quête"))
    end))
    row.Share:SetScript("OnLeave", guarded(function(self)
        Shared.hideTip(self)
        showShare(self:GetParent())
    end))
    row.Share:Hide()
    -- Links in objective text can be clicked, as Blizzard's lines allow.
    row:SetHyperlinksEnabled(true)
    row:SetScript("OnHyperlinkClick", guarded(function(self, link, text, mouse)
        if SetItemRef then
            SetItemRef(link, text, mouse, self)
        end
    end))
    ns.Motion.AddRow(row)
    ns.Drag.Register(row, "quest")
    row:SetScript("OnClick", guarded(onRowClick))
    row:SetScript("OnEnter", guarded(function(self)
        hovered = self
        Shared.wake()
        self.hover = true
        colourRow(self)
        showShare(self)
        rowTooltip(self)
    end))
    row:SetScript("OnLeave", guarded(function(self)
        if hovered == self then
            hovered = nil
        end
        self.hover = false
        colourRow(self)
        showShare(self)
        Shared.hideTip(self)
    end))
    return row
end

local function objectiveLine(row, i)
    local l = row.lines[i]
    if l then
        return l
    end
    l = {}
    l.Dash = row:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    l.Dash:SetText(ns.G("QUEST_DASH", "- "))
    l.Text = row:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    l.Text:SetJustifyH("LEFT")
    l.Check = row:CreateTexture(nil, "ARTWORK")
    l.Check:SetAtlas("ui-questtracker-tracker-check", false)
    l.Check:SetSize(16, 16)
    ns.Motion.AddLine(row, l)
    row.lines[i] = l
    return l
end

-- A progress bar under its objective, as ObjectiveTrackerProgressBarTemplate draws it.
-- Blizzard's bar art: a blue bar on dark blue inside the skills bar's border.
local function styleBar(bar, borderHeight)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.26, 0.42, 1)
    bar.Bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bar.Bg:SetAllPoints()
    bar.Bg:SetColorTexture(0.04, 0.07, 0.18)
    local border = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
    bar.BorderLeft = bar:CreateTexture(nil, "ARTWORK")
    bar.BorderLeft:SetTexture(border)
    bar.BorderLeft:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
    bar.BorderLeft:SetSize(9, borderHeight)
    bar.BorderLeft:SetPoint("LEFT", -3, 0)
    bar.BorderRight = bar:CreateTexture(nil, "ARTWORK")
    bar.BorderRight:SetTexture(border)
    bar.BorderRight:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
    bar.BorderRight:SetSize(9, borderHeight)
    bar.BorderRight:SetPoint("RIGHT", 3, 0)
    bar.BorderMid = bar:CreateTexture(nil, "ARTWORK")
    bar.BorderMid:SetTexture(border)
    bar.BorderMid:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
    bar.BorderMid:SetPoint("TOPLEFT", bar.BorderLeft, "TOPRIGHT")
    bar.BorderMid:SetPoint("BOTTOMRIGHT", bar.BorderRight, "BOTTOMLEFT")
end

local function progressBar(row)
    if row.Progress then
        return row.Progress
    end
    local bar = newFrame("StatusBar", row)
    bar.kaliQuestOwn = true
    bar:SetSize(180, 15)
    bar:SetMinMaxValues(0, 100)
    styleBar(bar, 22)
    bar.Label = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    bar.Label:SetPoint("CENTER", 0, -1)
    row.Progress = bar
    return bar
end

-- As ObjectiveTrackerTimerBarMixin: the time left, white, then towards yellow under two thirds and red under one
-- third, held at 0 a second before the entry redraws.
local function timerTick(t)
    local left = t.duration - (GetTime() - t.start)
    t.Bar:SetValue(math.max(0, left))
    if left < -1 then
        if not t.expired then
            t.expired = true
            ns.RequestRefresh()
        end
        return
    end
    left = math.max(0, left)
    t.Label:SetText(SecondsToClock and SecondsToClock(left) or tostring(math.floor(left)))
    local share = t.duration > 0 and left / t.duration or 0
    if share > 0.66 then
        t.Label:SetTextColor(1, 1, 1)
    elseif share > 0.33 then
        t.Label:SetTextColor(1, 1, (share - 0.33) / 0.33)
    else
        t.Label:SetTextColor(1, share / 0.33, 0)
    end
end

local function timerBar(row, n)
    row.timers = row.timers or {}
    local t = row.timers[n]
    if t then
        return t
    end
    t = newFrame("Frame", row)
    t:SetSize(192, 20)
    t.Label = t:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    t.Label:SetJustifyH("LEFT")
    t.Label:SetPoint("LEFT")
    t.Bar = newFrame("StatusBar", t)
    t.Bar:SetSize(128, 10)
    t.Bar:SetPoint("RIGHT", -4, 0)
    styleBar(t.Bar, 14)
    t:SetScript("OnUpdate", guarded(timerTick))
    t:Hide()
    row.timers[n] = t
    return t
end

function Rows.NewMoved()
    local m = newFrame("Button", Tracker.frames.content)
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    m.SepTop = Shared.separator(m)
    m.SepBottom = Shared.separator(m)
    m.Title = m:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    m.Title:SetJustifyH("LEFT")
    m.Title:SetWordWrap(false)
    m.Title:SetPoint("LEFT", 0, 0)
    paint(m.Title, COLOR.moved)
    m.Back = Shared.iconButton(m, "common-icon-undo", 14, 14, 0.55, L.BRING_BACK)
    m.Back:SetPoint("RIGHT", 0, 0)
    m.Back:SetScript("OnClick", guarded(function(self)
        local line = self:GetParent().line
        ns.Menus.MoveTo(line.quest.id, nil)
    end))
    m:SetScript("OnClick", guarded(onRowClick))
    m:SetScript("OnEnter", guarded(function(self)
        hovered = self
        Shared.wake()
        paint(self.Title, COLOR.movedHover)
        rowTooltip(self)
    end))
    m:SetScript("OnLeave", guarded(function(self)
        if hovered == self then
            hovered = nil
        end
        paint(self.Title, COLOR.moved)
        Shared.hideTip(self)
    end))
    return m
end

local function onEntryClick(self, button)
    local e = self.line and self.line.entry
    if e then
        ns.Sections.Click(self, e, button)
    end
end

-- A tracked recipe or achievement: a box as a quest's, its title and lines, with no level, markers or buttons.
function Rows.NewEntry()
    local row = newFrame("Button", Tracker.frames.content)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.Bg = row:CreateTexture(nil, "BACKGROUND")
    row.Bg:SetColorTexture(0, 0, 0, 1)
    row.SepTop = Shared.separator(row)
    row.SepBottom = Shared.separator(row)
    row.Title = row:CreateFontString(nil, "ARTWORK", "KaLiQuestLineFont")
    row.Title:SetJustifyH("LEFT")
    row.Title:SetMaxLines(2)
    row.Title:SetPoint("TOPLEFT", 0, 0)
    row.lines = {}
    ns.Motion.AddRow(row)
    row:SetScript("OnClick", guarded(onEntryClick))
    row:SetScript("OnEnter", guarded(function(self)
        Shared.wake()
        self.hover = true
        colourRow(self)
    end))
    row:SetScript("OnLeave", guarded(function(self)
        self.hover = false
        colourRow(self)
    end))
    return row
end

-- What a row shows -------------------------------------------------------------------------------------------

-- Other addons' hooks on Blizzard's AddBlock see the row as one of its blocks, so Spoken adds its button. The
-- stand-in keeps Blizzard's own body from writing into the real section. See docs/addon-extensions.md.
local standIn
local function fireAddBlock(row)
    local section = QuestObjectiveTracker
    if not (section and section.AddBlock) then
        return
    end
    standIn = standIn or setmetatable({ CanFitBlock = function()
        return false
    end }, { __index = section })
    pcall(section.AddBlock, standIn, row)
end

-- Room taken at the right of the title by buttons other addons put on the row. Frames of this addon's own carry
-- kaliQuestOwn.
local function foreignRoom(row)
    local room = 0
    for _, child in ipairs({ row:GetChildren() }) do
        if child:IsShown() and not child.kaliQuestOwn then
            room = math.max(room, (child:GetWidth() or 0) + 2)
        end
    end
    return room
end

-- The next step, for the focused quest, as Blizzard's shows it. May be empty on Forever.
local function waypointText(q)
    local text = C_QuestLog.GetNextWaypointText and C_QuestLog.GetNextWaypointText(q.id)
    return text ~= "" and text or nil
end

-- The lines under a quest's title, as Blizzard's tracker writes them. Each objective keeps its index, so its
-- animation finds it. A completed quest keeps its objectives, checked, while they check off or until combat ends,
-- and a sequenced quest shows only the steps it has reached.
local function objectivesOf(q, superTracked)
    local out = {}
    local holding = ns.Motion.HoldsLines(q)
    local focused = superTracked == q.id
    local function waypoint(optional)
        local text = waypointText(q)
        if text then
            out[#out + 1] = { text = optional and ns.G("WAYPOINT_OBJECTIVE_FORMAT_OPTIONAL", "%s"):format(text) or text, style = "normal", dash = true }
        end
        return text
    end
    if q.complete and not holding then
        if q.isAutoComplete then
            out[1] = { text = ns.G("QUEST_WATCH_QUEST_COMPLETE", "Quête terminée"), style = "normal", dash = true }
            out[2] = { text = ns.G("QUEST_WATCH_CLICK_TO_COMPLETE", "(cliquer pour terminer)"), style = "normal", dash = true }
        else
            local text = q.logIndex and GetQuestLogCompletionText(q.logIndex)
            if text and text ~= "" then
                if focused then
                    waypoint(true)
                end
                out[#out + 1] = { text = text, style = "normal" }
            elseif not waypoint(false) then
                out[1] = { text = ns.G("QUEST_WATCH_QUEST_READY", "À rendre"), style = "complete" }
            end
        end
    elseif q.failed then
        out[1] = { text = ns.G("FAILED", "Echec"), style = "failed" }
    else
        if focused and not holding then
            waypoint(true)
        end
        local sequenced = IsQuestSequenced and IsQuestSequenced(q.id)
        for i = 1, q.logIndex and GetNumQuestLeaderBoards(q.logIndex) or 0 do
            local text, objectiveType, finished = GetQuestLogLeaderBoard(i, q.logIndex, true)
            finished = finished or holding
            if text and text ~= "" and (holding or not finished or ns.Motion.ShowsFinishedStep(q, i, sequenced)) then
                local progress = objectiveType == "progressbar" and not finished
                -- The percent is kept with the line, so a row fading out of the log still shows it.
                out[#out + 1] = { index = i, text = text, style = finished and "complete" or "normal", dash = not finished, check = finished,
                    progress = progress, percent = progress and GetQuestProgressBarPercent and GetQuestProgressBarPercent(q.id) or 0 }
            end
        end
        local required = not holding and C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(q.id) or 0
        local money = GetMoney()
        if required > money and GetMoneyString then
            out[#out + 1] = { text = GetMoneyString(money) .. " / " .. GetMoneyString(required), style = "normal", dash = true }
        end
    end
    return out
end

local function levelColour(q)
    if GetCVarBool and not GetCVarBool("showQuestDifficultyColor") then
        return COLOR.title
    end
    if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer and GetDifficultyColor then
        local c = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(q.id))
        if c and c.r then
            return { c.r, c.g, c.b }
        end
    end
    return COLOR.title
end

-- Party members on the quest, counting the player, as the native log's [2].
local function partyPrefix(q)
    if not (IsInGroup() and QuestUtils_GetNumPartyMembersOnQuest) then
        return ""
    end
    local n = QuestUtils_GetNumPartyMembersOnQuest(q.id) or 0
    return n > 0 and string.format("|cffb8a878[%d]|r ", n + 1) or ""
end

local drawnLines = {} -- questID -> the lines last drawn, for a row that keeps its place while it leaves

function Rows.LinesOf(id)
    return drawnLines[id]
end

function Rows.ForgetLines(quests)
    for id in pairs(drawnLines) do
        if not quests[id] then
            drawnLines[id] = nil
        end
    end
end

-- A box's background, separators and hit rect. The whole box takes clicks, badge and margins included, Ikar's ruling.
local function boxChrome(f, ctx, last)
    local left = -(ctx.gutter + 7)
    f.gutter = -left
    f:SetHitRectInsets(left, -2, -3, -3)
    if f.Bg then
        f.Bg:ClearAllPoints()
        f.Bg:SetPoint("TOPLEFT", f, "TOPLEFT", left, 3)
        f.Bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -3)
    end
    f.SepTop:ClearAllPoints()
    f.SepTop:SetPoint("TOPLEFT", f, "TOPLEFT", left, 3)
    f.SepTop:SetWidth(ctx.rowWidth - left + 2)
    f.SepBottom:ClearAllPoints()
    f.SepBottom:SetPoint("TOPLEFT", f, "BOTTOMLEFT", left, -3)
    f.SepBottom:SetWidth(ctx.rowWidth - left + 2)
    f.SepBottom:SetShown(last == true)
end

-- Icons only where the row's place doesn't already say it, in the plan's order (Markers). At most three show, and
-- no tooltip names them, Ikar's ruling on 2026-11-10. Dungeon, raid and PvP show only outside their own category,
-- as icons rather than the "(Donjon)" text, Ikar's ruling on 2026-11-06.
local MARKERS = {
    { kind = "dungeon", atlas = "questlog-questtypeicon-dungeon", tags = ns.Filter.TAGS.dungeon, home = "instances", name = "CALENDAR_TYPE_DUNGEON", fallback = "Donjon" },
    { kind = "raid", atlas = "questlog-questtypeicon-raid", tags = ns.Filter.TAGS.raid, home = "instances", name = "RAID", fallback = "Raid" },
    { kind = "pvp", atlas = "questlog-questtypeicon-pvp", tags = ns.Filter.TAGS.pvp, home = "pvp", name = "CALENDAR_TYPE_PVP", fallback = "JcJ" },
}
local SHOWN_MARKERS = 3

-- A marker switched off in the options doesn't show.
local function markersOf(q, inGroup)
    local out = {}
    local on = ns.db.options.markers
    local function add(kind, atlas, label, number, short)
        if on[kind] ~= false then
            out[#out + 1] = { atlas = atlas, label = label, number = number, short = short }
        end
    end
    local world = ns.Tracking.World
    if inGroup and world:HasQuest(q.id) and not world:IsWatched(q.id) then
        add("offlist", "waypoint-mappin-minimap-untracked", L.PAST_LIMIT, nil, L.PAST_LIMIT_SHORT)
    end
    local timeAllowed = C_QuestLog.GetTimeAllowed and C_QuestLog.GetTimeAllowed(q.id)
    if timeAllowed and timeAllowed > 0 then
        add("timed", "questlog-questtypeicon-clockyellow", L.FILTER_V_TIMED)
    end
    local size = q.suggestedGroup or 0
    if size > 1 then
        add("size", "questlog-questtypeicon-group", string.format(L.FILTER_V_SIZE, size), size)
    end
    local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(q.id)
    local tagID = type(tag) == "table" and tag.tagID
    for _, m in ipairs(MARKERS) do
        if tagID and m.tags[tagID] and (inGroup or q.category ~= m.home) then
            add(m.kind, m.atlas, ns.G(m.name, m.fallback))
        end
    end
    local frequency = q.frequency or FREQUENCY.Default
    if q.repeatable and frequency == FREQUENCY.Default then
        add("repeatable", "questrepeatableturnin", L.FILTER_V_REPEATABLE)
    elseif frequency == FREQUENCY.Daily or frequency == FREQUENCY.ResetByScheduler then
        add("daily", "questlog-questtypeicon-daily", frequency == FREQUENCY.ResetByScheduler and L.FILTER_V_SCHEDULED or L.FILTER_V_DAILY)
    elseif frequency == FREQUENCY.Weekly then
        add("weekly", "questlog-questtypeicon-weekly", L.FILTER_V_WEEKLY)
    end
    if tagID == ns.Filter.TAG.legendary then
        add("legendary", "questlog-questtypeicon-legendary", L.FILTER_V_LEGENDARY)
    end
    -- In Suivi a class quest's place no longer says so.
    if inGroup and (q.headerKind == "ownclass" or q.headerKind == "class") then
        add("class", "questlog-questtypeicon-class", ns.G("CLASS", "Classe"))
    end
    return out
end

-- Inline in the title, held to its last word by no-break spaces, so a marker never wraps onto a line alone. As the
-- option says: icons, a group size following its icon as a number; text in brackets, as the bench's; or none.
local function markerText(markers)
    local style = ns.db.options.markerStyle
    local parts = {}
    if style == "none" then
        return ""
    end
    for i = 1, math.min(#markers, SHOWN_MARKERS) do
        local m = markers[i]
        if style == "text" then
            parts[i] = string.format("\194\160|cffb0b0b0(%s)|r", m.number or m.short or m.label)
        else
            parts[i] = string.format("\194\160|A:%s:%d:%d|a", m.atlas, layout.markerSize, layout.markerSize) .. (m.number or "")
        end
    end
    return table.concat(parts)
end

-- The bare title, as other addons marked it in the hidden copy.
local function titleOf(row, q, width)
    local source = row.TitleSource
    source:SetWidth(width)
    row.settingTitle = true
    source:SetText(q.title)
    row.settingTitle = false
    return source:GetText() or q.title
end

local function drawPOI(row, q, ctx, superTracked)
    if not row.POI then
        return
    end
    if not ctx.poi or q.leaving then
        row.POI:Hide()
        return
    end
    local poi = row.POI
    if poi:GetQuestID() ~= q.id then
        poi:SetQuestID(q.id)
    end
    local style = POIButtonUtil and POIButtonUtil.Style
    if style then
        poi:SetStyle(q.complete and style.QuestComplete or style.QuestInProgress)
    end
    poi:SetSelected(superTracked == q.id)
    poi:UpdateButtonStyle()
    poi:ClearAllPoints()
    poi:SetPoint("TOPRIGHT", row.Title, "TOPLEFT", -5, 5)
    poi:Show()
    poi:EnableMouse(not Shared.EditMode())
end

-- One objective line under the title at height, as Blizzard's draws it. Returns the line, its dash's width and the
-- height below it.
local function placeLine(row, i, o, height, width)
    local l = objectiveLine(row, i)
    l.style = o.style
    local y = -(height + LINE_GAP)
    l.Dash:ClearAllPoints()
    l.Dash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, y)
    l.Dash:Show()
    -- A finished objective hides its dash but keeps its room, as Blizzard's does.
    l.Dash:SetAlpha(o.dash and 1 or 0)
    local dashWidth = l.Dash:GetStringWidth()
    l.Text:ClearAllPoints()
    l.Text:SetPoint("TOPLEFT", row, "TOPLEFT", dashWidth, y)
    l.Text:SetWidth(width - dashWidth)
    l.Text:SetText(o.text)
    l.Text:Show()
    l.Text:SetAlpha(1)
    l.Check:ClearAllPoints()
    l.Check:SetPoint("TOPLEFT", row, "TOPLEFT", -10, y + 2)
    l.Check:SetShown(o.check == true)
    l.Check:SetAlpha(1)
    return l, dashWidth, height + LINE_GAP + l.Text:GetStringHeight()
end

local function hideLinesFrom(row, first)
    for i = first, #row.lines do
        local l = row.lines[i]
        l.Dash:Hide()
        l.Text:Hide()
        l.Check:Hide()
    end
    row.shownLines = first - 1
end

local function drawPicked(row, leaving)
    local on = not leaving and picked[row.id] == true
    row.picked = on
    row.Picked:SetShown(on)
    row.PickedEdge:SetShown(on)
    if on then
        row.Picked:ClearAllPoints()
        row.Picked:SetPoint("TOPLEFT", row, "TOPLEFT", -row.gutter, 3)
        row.Picked:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -3)
        row.PickedEdge:ClearAllPoints()
        row.PickedEdge:SetPoint("TOPLEFT", row.Picked, "TOPLEFT")
        row.PickedEdge:SetPoint("BOTTOMLEFT", row.Picked, "BOTTOMLEFT")
    end
end

function Rows.DrawRow(row, line, ctx, superTracked)
    local q = line.quest
    local leaving = q.leaving ~= nil
    local editMode = Shared.EditMode()
    row.line = line
    row.id = q.id
    row:SetWidth(ctx.rowWidth)
    if not leaving then
        row.FadeOut:Stop()
        row:SetAlpha(1)
    end
    fireAddBlock(row)

    -- The right edge, right to left as Blizzard's: other addons' buttons, the find-group eye, then the item.
    local right = -foreignRoom(row)
    local hasEye = not leaving and row.Eye ~= nil and ns.db.options.findGroup and not q.complete and ns.Filter.CanFindGroup(q.id)
    if row.Eye then
        row.Eye:SetShown(hasEye)
        if hasEye then
            row.Eye:ClearAllPoints()
            row.Eye:SetPoint("TOPRIGHT", row, "TOPRIGHT", right + 5, 2)
            row.Eye:SetUp(q.id)
            row.Eye:EnableMouse(not editMode)
            right = right + 5 - 30 - 2
        end
    end
    local hasItem = false
    if leaving then
        -- A reused row may still hold another quest's item.
        row.item = nil
        row.ItemSlot:Hide()
    else
        hasItem = ns.Items.Slot(row, q, right)
    end
    if hasItem then
        right = right - 26 - 2
    end
    -- Only when it can do something: in a group, the quest shareable, and someone in the party without it. Its room
    -- stays taken while "only on hover" hides it, so the title doesn't rewrap under the pointer.
    local canShare = not leaving and IsInGroup() and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(q.id)
        and QuestUtils_GetNumPartyMembersOnQuest and QuestUtils_GetNumPartyMembersOnQuest(q.id) < GetNumSubgroupMembers()
    row.canShare = canShare and true or false
    if row.canShare then
        row.Share:ClearAllPoints()
        row.Share:SetPoint("TOPRIGHT", row, "TOPRIGHT", right, -2)
        row.Share:EnableMouse(not editMode)
        right = right - 22 - 2
    end
    showShare(row)
    local textWidth = ctx.rowWidth + right
    -- Other addons' buttons are only as tall as the title, so alone they leave the lines their full width.
    local linesWidth = (hasEye or hasItem or row.canShare) and textWidth or ctx.rowWidth

    -- Centred on the title's first line, which it overhangs a little, as on the bench.
    row.Badge:ClearAllPoints()
    row.Badge:SetPoint("RIGHT", row, "TOPLEFT", -(4 + (ctx.poi and POI_ROOM or 0)), ctx.badgeY)
    row.Badge:SetSize(ctx.badgeWidth, ctx.badgeHeight)
    if row.levelSize ~= ctx.levelSize then
        local file, _, flags = row.Title:GetFont()
        if file then
            row.Level:SetFont(file, ctx.levelSize, flags or "")
        end
        row.levelSize = ctx.levelSize
    end
    local elite = C_QuestLog.IsEliteQuest and C_QuestLog.IsEliteQuest(q.id)
    row.Level:SetText((q.difficultyLevel or q.level or 0) .. (elite and "+" or ""))
    paint(row.Level, levelColour(q))

    row.Title:SetWidth(textWidth)
    row.markers = leaving and {} or markersOf(q, line.group ~= nil)
    row.area = not leaving and ns.Area.Is(q.id) ~= nil
    local areaMark = row.area and string.format(Shared.AREA_ARROW, ctx.size, math.floor(ctx.size * 0.75 + 0.5)) .. " " or ""
    row.Title:SetText(areaMark .. partyPrefix(q) .. titleOf(row, q, textWidth) .. markerText(row.markers))
    row.HeadGlow:SetWidth(ctx.rowWidth)
    local height = row.Title:GetStringHeight()
    row.TitleHolder:SetSize(textWidth, height)
    drawPOI(row, q, ctx, superTracked)

    local objectives = leaving and (q.leaving.lines or {}) or objectivesOf(q, superTracked)
    drawnLines[q.id] = objectives
    local watched = ns.Tracking.World:IsWatched(q.id)
    local fade = not leaving and ns.Motion.StartFade(q.id)
    local barShown = false
    for i, o in ipairs(objectives) do
        local l, dashWidth
        l, dashWidth, height = placeLine(row, i, o, height, linesWidth)
        if not leaving and o.index then
            ns.Motion.PlayLine(q.id, o.index, l, watched)
        end
        if fade then
            ns.Motion.FadeLines(l)
        end
        if o.progress and not barShown then
            local bar = progressBar(row)
            local percent = o.percent or 0
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", row, "TOPLEFT", dashWidth + 3, -(height + 5))
            bar:SetValue(percent)
            bar.Label:SetText(string.format("%d%%", percent))
            bar:Show()
            barShown = true
            height = height + 25
        end
    end
    hideLinesFrom(row, #objectives + 1)
    if row.Progress and not barShown then
        row.Progress:Hide()
    end
    if hasItem then
        height = math.max(height, 26)
    end
    if hasEye then
        height = math.max(height, 28)
    end
    if row.canShare then
        height = math.max(height, 22)
    end
    row:SetHeight(height)
    boxChrome(row, ctx, line.last)
    row.selected = superTracked == q.id
    drawPicked(row, leaving)
    colourRow(row)
    if leaving then
        ns.Motion.PlayLeave(row, q.id)
    else
        ns.Motion.PlayRow(row, q.id, ns.db.options.progressFlash ~= false)
    end
    return height
end

function Rows.DrawMoved(m, line, ctx)
    m.line = line
    m:SetWidth(ctx.rowWidth)
    m.Title:SetWidth(ctx.rowWidth - 18)
    m.Title:SetText(line.quest.title)
    local height = m.Title:GetStringHeight()
    m:SetHeight(height)
    m.Back:EnableMouse(not Shared.EditMode())
    boxChrome(m, ctx, line.last)
    return height
end

local entriesBefore -- every recipe and achievement read last time, drawn or not, so only a newly tracked one fades in

function Rows.SetEntriesSeen(entries)
    entriesBefore = entries
end

function Rows.DrawEntry(row, line, ctx)
    local e = line.entry
    row.line = line
    row:SetWidth(ctx.rowWidth)
    if not e.leaving then
        row.FadeOut:Stop()
        row:SetAlpha(1)
    end
    row.Title:SetWidth(ctx.rowWidth)
    row.Title:SetText(e.title)
    row.HeadGlow:SetWidth(ctx.rowWidth)
    local height = row.Title:GetStringHeight()
    local timers = 0
    for i, o in ipairs(e.lines) do
        local _, dashWidth
        _, dashWidth, height = placeLine(row, i, o, height, ctx.rowWidth)
        if o.timer then
            timers = timers + 1
            local t = timerBar(row, timers)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", row, "TOPLEFT", dashWidth, -(height + LINE_GAP))
            t.duration, t.start, t.expired = o.timer.duration, o.timer.start, false
            t.Bar:SetMinMaxValues(0, o.timer.duration)
            t:Show()
            timerTick(t)
            height = height + LINE_GAP + t:GetHeight()
        end
    end
    for i = timers + 1, #(row.timers or {}) do
        row.timers[i]:Hide()
    end
    hideLinesFrom(row, #e.lines + 1)
    row:SetHeight(height)
    boxChrome(row, ctx, line.last)
    colourRow(row)
    if e.leaving then
        ns.Sections.PlayEarned(row, e)
    elseif entriesBefore and not entriesBefore[e.key] then
        -- Newly tracked, as Blizzard's AddAnim: the glow sweeps the title as the entry fades in.
        row.FadeIn:Stop()
        row.FadeIn:Play()
        row.HeadSweep:Stop()
        row.HeadSweep:Play()
    end
    return height
end

-- What every row of a layout shares: the text size, map buttons, and the columns left of the title.
function Rows.Context()
    local size = ns.Fonts.Size()
    -- The level sits in a column left of the title, so a wrapped title keeps its left edge. Map buttons, when the
    -- world map's quest objectives are on, sit between the two.
    local badge = math.ceil(size * 1.75)
    local poi = GetCVarBool and GetCVarBool("questPOI") and true or false
    local indent = math.max(layout.questIndent, badge + (poi and 26 or 5))
    return {
        size = size,
        poi = poi,
        gutter = badge + (poi and POI_ROOM or 0),
        indent = indent,
        rowWidth = layout.width - indent,
        badgeWidth = badge,
        badgeHeight = math.floor(size * 1.3 + 0.5),
        badgeY = -math.floor(size * 0.51 + 0.5),
        levelSize = math.floor(size * 0.75 + 0.5),
    }
end

-- Picking ----------------------------------------------------------------------------------------------------

function Rows.TogglePick(id)
    picked[id] = not picked[id] or nil
    ns.RequestRefresh()
end

function Rows.ClearPicked()
    if next(picked) then
        wipe(picked)
        ns.RequestRefresh()
    end
end

function Rows.IsPicked(id)
    return picked[id] == true
end

-- The picked quests, top to bottom.
function Rows.Picked()
    local ids = {}
    for _, id in ipairs(pickOrder) do
        if picked[id] then
            ids[#ids + 1] = id
        end
    end
    return ids
end

-- After each layout: only rows drawn stay picked, so a closed group, a search or a quest leaving lets them go.
function Rows.KeepPicked(rows)
    wipe(pickOrder)
    local drawn = {}
    for _, r in ipairs(rows) do
        local q = r.frame.line and r.frame.line.quest
        if q and not q.leaving then
            pickOrder[#pickOrder + 1] = r.id
            drawn[r.id] = true
        end
    end
    for id in pairs(picked) do
        if not drawn[id] then
            picked[id] = nil
        end
    end
end
