-- The tracker on screen: builds its frames, draws them from Layout.Lines at each refresh, scrolls, and turns it on
-- and off. Rows are ordinary frames, so they can open, close and scroll in combat. Rows, headers, menus and the
-- padlock are in their own files, and the pieces they share in Widgets.lua.
local _, ns = ...
local L = ns.L
local Tracker = ns.Tracker
local Shared = Tracker.Shared
local layout = Shared.layout
local guarded, newFrame = Shared.guarded, Shared.newFrame
local Pool, acquire, finish = Shared.Pool, Shared.acquire, Shared.finish

local ROW_GAP = 6 -- each background reaches 3 past its row, so rows touch
local RIGHT_ROOM = 24
local BOTTOM_PAD = 12
local BACKGROUND_PAD = 10 -- below the list, as Blizzard's bottomModulePadding
local WHEEL_STEP = 40
local FIXED_GAP = 6 -- Blizzard's first section sits 6 under the title, as the search box, status and popups do

local root, title, scroll, scrollBar, content, background
local active = false
local offset = 0
local maxOffset = 0
local hadPosition
local hooksDone = false
local questRows = {} -- questID -> its row in the last layout

function Tracker.IsActive()
    return active
end

-- The quest rows of the last layout, by quest, for the item buttons.
function Tracker.QuestRows()
    return questRows
end

-- Scrolling --------------------------------------------------------------------------------------------------

-- Blizzard's MinimalScrollBar, right of the rows in the host's extra 12. Invisible unless the list is scrolling or
-- the pointer is on it, Ikar's ruling.
local barToken = 0
local function showBar()
    if not scrollBar then
        return
    end
    scrollBar.FadeOut:Stop()
    scrollBar:SetAlpha(1)
    barToken = barToken + 1
    local token = barToken
    C_Timer.After(0.8, guarded(function()
        if token ~= barToken then
            return
        end
        if scrollBar:IsMouseOver() then
            showBar()
        else
            scrollBar.FadeOut:Play()
        end
    end))
end

local function buildScrollBar()
    local template = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("MinimalScrollBar")
    if not (template and ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar) then
        return nil
    end
    local bar = newFrame("EventFrame", root, "MinimalScrollBar")
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
    if scroll.SetPanExtent then
        scroll:SetPanExtent(WHEEL_STEP)
    end
    bar:SetAlpha(0)
    bar.FadeOut = bar:CreateAnimationGroup()
    local fade = bar.FadeOut:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.4)
    bar.FadeOut:SetToFinalAlpha(true)
    local function onEnter()
        Shared.wake()
        showBar()
    end
    -- Locked in combat the bar doesn't move, so pressing it flashes the padlock as other refused clicks do.
    local function onMouseDown()
        if InCombatLockdown() then
            Shared.refusedByLock()
        end
    end
    for _, part in ipairs({ bar.Track, bar.Track and bar.Track.Thumb, bar.Back, bar.Forward }) do
        if part and part.HookScript then
            part:HookScript("OnEnter", guarded(onEnter))
            part:HookScript("OnMouseDown", guarded(onMouseDown))
        end
    end
    return bar
end

local function onWheel(_, delta)
    if InCombatLockdown() and Shared.refusedByLock() then
        return
    end
    if scrollBar then
        scrollBar:ScrollStepInDirection(-delta)
    else
        scroll:SetVerticalScroll(math.max(0, math.min(maxOffset, offset - delta * WHEEL_STEP)))
    end
end

-- Scrolling moves rows away from their item buttons, which only matters in combat, so there the padlock decides.
-- The scrollbar's own arrows and thumb come through here too.
local function onScrolled(_, value)
    if math.abs(value - offset) < 0.5 then
        return
    end
    -- A list grown shorter ends sooner, whatever the padlock says. Held there, the bar can't push it back.
    local held = math.min(offset, scroll:GetVerticalScrollRange())
    if math.abs(value - held) < 0.5 then
        offset = value
        ns.Items.Sync()
        return
    end
    if InCombatLockdown() and Shared.refusedByLock() then
        offset = held
        scroll:SetVerticalScroll(held)
        return
    end
    offset = value
    showBar()
    ns.Items.Sync()
end

-- Building ---------------------------------------------------------------------------------------------------

local function build()
    Shared.ApplyOptions()
    ns.Fonts.Apply()
    local width = layout.width
    -- For the other files, /kq status and the offline smoke test.
    Tracker.frames = {}
    Shared.frames = Tracker.frames
    local frames = Tracker.frames
    root = CreateFrame("Frame", "KaLiQuestTracker", nil)
    root:SetParent(UIParent)
    root:SetSize(width, 600)
    frames.root = root

    -- Not NineSlicePanelTemplate: its OnLoad reads the parent, which newFrame only sets after CreateFrame.
    background = newFrame("Frame", root)
    if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        NineSliceUtil.ApplyLayoutByName(background, "UniqueCornersLayout", "common-opacity-background")
    end
    frames.background = background

    scroll = newFrame("ScrollFrame", root)
    content = newFrame("Frame", scroll)
    content:SetSize(width + Shared.SIDE + RIGHT_ROOM, 1)
    scroll:SetScrollChild(content)
    frames.scroll, frames.content = scroll, content
    scrollBar = buildScrollBar()
    frames.scrollBar = scrollBar
    scroll:SetScript("OnMouseWheel", guarded(onWheel))
    scroll:HookScript("OnVerticalScroll", guarded(onScrolled))

    -- Between the title and the list: the alert line, the search box, its status line and popups.
    local fixed = newFrame("Frame", root)
    fixed:SetSize(width, 1)
    frames.fixed = fixed
    ns.Coverage.Build(fixed)
    ns.Search.Build(fixed)
    ns.Popups.Build(fixed)

    title = ns.Headers.BuildTitle(root)
    frames.title = title
    frames.renameBox = ns.Headers.BuildRenameBox(content)
    Tracker.pools = { bar = Pool(ns.Headers.NewBar), group = Pool(ns.Headers.NewGroup), row = Pool(ns.Rows.NewRow),
        moved = Pool(ns.Rows.NewMoved), entry = Pool(ns.Rows.NewEntry) }
    ns.Items.Build()
end

-- Drawing ----------------------------------------------------------------------------------------------------

local function place(f, x, y)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", Shared.SIDE + x, -y)
end

-- What the last layout read, so a quest leaving the log keeps its place while it fades.
local lastQuests, lastOrder, lastPlacement = {}, {}, {}
local heldBack = {} -- quests accepted during a fight, drawn once it ends
local expandPending = false -- a popup arrived during a fight, so the tracker opens once it ends

local function snapshot(id)
    local q = lastQuests[id]
    if not q then
        return nil
    end
    local after
    for i, other in ipairs(lastOrder) do
        if other == id then
            after = lastOrder[i - 1]
            break
        end
    end
    local p = lastPlacement[id]
    return { quest = q, after = after, groupID = p and p.groupID, index = p and p.index, lines = ns.Rows.LinesOf(id) }
end

-- Leaving quests go back into the log and their group as they were, flagged so their row only fades.
local function withLeaving(quests, order, groups)
    local copy
    for id, l in pairs(ns.Motion.Leaving()) do
        if not quests[id] then
            local q = {}
            for k, v in pairs(l.quest) do
                q[k] = v
            end
            q.logIndex = nil
            q.leaving = l
            quests[id] = q
            local at = #order + 1
            for i, other in ipairs(order) do
                if other == l.after then
                    at = i + 1
                    break
                end
            end
            table.insert(order, at, id)
            if l.groupID then
                if not copy then
                    copy = {}
                    for i, g in ipairs(groups) do
                        copy[i] = { id = g.id, name = g.name, quests = { unpack(g.quests) } }
                    end
                end
                for _, g in ipairs(copy) do
                    if g.id == l.groupID then
                        local present = false
                        for _, other in ipairs(g.quests) do
                            present = present or other == id
                        end
                        if not present then
                            table.insert(g.quests, math.min(l.index or #g.quests + 1, #g.quests + 1), id)
                        end
                    end
                end
            end
        end
    end
    return copy or groups
end

local function drawAll()
    if not active or not ns.model or not ns.categories then
        return
    end
    local db = ns.db
    Shared.ApplyOptions()
    ns.Fonts.Apply()
    local width = layout.width
    ns.Host.SetWidth(width)
    local quests, order = ns.QuestLog.Read(ns.categories.Classify)
    ns.Area.Note(quests, ns.Motion.Scan(quests, InCombatLockdown()))
    ns.Filter.Forget(quests)
    local extra = ns.Sections.Read()
    local entriesNow = {}
    for _, section in ipairs(extra) do
        for _, e in ipairs(section.entries) do
            entriesNow[e.key] = true
        end
    end
    local _, instanceType = IsInInstance()
    local ruled = C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule and Enum.GameRule.ObjectiveTrackerDisabled
        and C_GameRules.IsGameRuleActive(Enum.GameRule.ObjectiveTrackerDisabled)
    -- As Blizzard's: no quests in arenas, and nothing at all where a game rule turns the tracker off.
    if (#order == 0 and #extra == 0) or instanceType == "arena" or ruled then
        root:Hide()
        ns.Sections.ReleaseAdopted()
        ns.Items.Sync()
        ns.Headers.FinishRename(true)
        return
    end
    local hasPosition = ObjectiveTrackerFrame:GetTop() ~= nil
    if hasPosition ~= hadPosition then
        hadPosition = hasPosition
        ns.Host.Place(root)
    end
    root:Show()

    -- A new popup opens a collapsed tracker, as Blizzard's does: in a fight, once it ends.
    local popups = ns.Popups.Read()
    if ns.Popups.Arrived(popups) then
        expandPending = true
    end
    if expandPending and not InCombatLockdown() then
        expandPending = false
        db.open.tracker = true
    end

    local logQuests = {}
    for id, q in pairs(quests) do
        logQuests[id] = q
    end
    lastOrder = {}
    for i, id in ipairs(order) do
        lastOrder[i] = id
    end
    -- Quests accepted during the fight wait for its end, so rows don't move under item buttons.
    for id in pairs(heldBack) do
        if quests[id] then
            quests[id] = nil
            for i = #order, 1, -1 do
                if order[i] == id then
                    table.remove(order, i)
                end
            end
        end
    end
    local groups = withLeaving(quests, order, db.groups)
    local tree = ns.Tree.Build(quests, order, groups, GetZoneText(), db.categoryOrder)
    tree.extra = extra
    Tracker.tree = tree
    local view = ns.Search.View(tree, quests)
    local lines, shownCount, totalCount = ns.Layout.Lines(tree, db.open, view)
    Tracker.lines = lines
    lastQuests = logQuests
    wipe(lastPlacement)
    for _, g in ipairs(db.groups) do
        for index, id in ipairs(g.quests) do
            lastPlacement[id] = { groupID = g.id, index = index }
        end
    end

    local timerRoom = ns.Host.PlaceTimer(width, ns.Fonts.Size())
    local rootHeight = db.options.height or ns.Host.Height()
    root:SetSize(width, rootHeight)
    root:SetAlpha((InCombatLockdown() and db.options.opacityCombat or db.options.opacity) / 100)
    local base = root:GetFrameLevel() or 1
    background:SetFrameLevel(base)
    scroll:SetFrameLevel(base + 2)
    title:SetFrameLevel(base + 20)
    ns.Headers.DrawTitle(title, root, timerRoom)

    -- Under the title: the search box, its status and popups. With any of them, the list starts at Blizzard's 6.
    local fixed = Tracker.frames.fixed
    local fixedGap = math.max(FIXED_GAP, layout.titleGap)
    fixed:ClearAllPoints()
    fixed:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -(timerRoom + Shared.TITLE_HEIGHT + fixedGap))
    fixed:SetWidth(width)
    -- Collapsed, the tracker is its title only, as Blizzard's: the box and popups come back when it opens.
    fixed:SetShown(db.open.tracker)
    local fixedHeight = 0
    if db.open.tracker then
        fixedHeight = ns.Coverage.Layout(fixed, width)
        fixedHeight = fixedHeight + ns.Search.Layout(fixed, view ~= nil, shownCount, totalCount, fixedHeight)
        fixedHeight = fixedHeight + ns.Popups.Layout(fixed, fixedHeight, width, ns.Fonts.Size(), popups)
    end
    fixed:SetHeight(math.max(1, fixedHeight))
    fixed:SetFrameLevel(base + 20)
    local listTop = timerRoom + Shared.TITLE_HEIGHT + (fixedHeight > 0 and fixedGap + fixedHeight or 0)

    local ctx = ns.Rows.Context()
    local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID() or 0
    local pools = Tracker.pools
    local renaming = ns.Headers.Renaming()
    ns.Headers.BeginDraw()
    ns.Sections.BeginAdopt()
    local renameTop, renameBottom
    local drawn = { bars = {}, groups = {}, quests = {}, entries = {} }
    local spans = { bars = {}, groups = {}, rows = {} }
    local openGroup -- the player's group whose span is still growing
    local barsNow = {}
    local y = fixedHeight > 0 and 0 or layout.titleGap
    for i, line in ipairs(lines) do
        local kind = line.kind
        if kind ~= "quest" and kind ~= "moved" then
            openGroup = nil
        end
        if kind == "bar" then
            if i > 1 then
                y = y + layout.barGap
            end
            local b = acquire(pools.bar)
            ns.Headers.DrawBar(b, line)
            place(b, 0, y)
            drawn.bars[line.id] = b
            barsNow[line.id] = true
            spans.bars[#spans.bars + 1] = { id = line.id, top = y, bottom = y + Shared.BAR_HEIGHT, frame = b, line = line }
            y = y + Shared.BAR_HEIGHT
        elseif kind == "group" then
            y = y + layout.groupGap
            local g = acquire(pools.group)
            ns.Headers.DrawGroup(g, line, ctx.size)
            place(g, layout.groupIndent, y)
            drawn.groups[line.group and ("g" .. line.group.id) or ("h" .. line.name)] = g
            if line.group and line.group.id == renaming then
                renameTop = y
                renameBottom = y + g:GetHeight()
            end
            if line.group then
                openGroup = { id = line.group.id, top = y - layout.groupGap / 2, bottom = y + g:GetHeight(), frame = g, line = line }
                spans.groups[#spans.groups + 1] = openGroup
            end
            y = y + g:GetHeight()
        elseif kind == "quest" then
            y = y + ROW_GAP
            local row = acquire(pools.row)
            place(row, ctx.indent, y)
            local top = y
            y = y + ns.Rows.DrawRow(row, line, ctx, superTracked)
            drawn.quests[line.quest.id] = row
            spans.rows[#spans.rows + 1] = { id = line.quest.id, groupID = line.group and line.group.id, top = top, bottom = y, frame = row }
            if openGroup and line.group then
                openGroup.bottom = y + ROW_GAP / 2
            end
        elseif kind == "moved" then
            y = y + ROW_GAP
            local m = acquire(pools.moved)
            place(m, ctx.indent, y)
            y = y + ns.Rows.DrawMoved(m, line, ctx)
        elseif kind == "entry" then
            y = y + ROW_GAP
            local e = acquire(pools.entry)
            place(e, ctx.indent, y)
            y = y + ns.Rows.DrawEntry(e, line, ctx)
            drawn.entries[line.entry.key] = e
        end
    end
    ns.Rows.SetEntriesSeen(entriesNow)
    for _, pool in pairs(pools) do
        finish(pool)
    end
    questRows = drawn.quests
    ns.Rows.KeepPicked(spans.rows)
    ns.Rows.ForgetLines(quests)
    ns.Headers.SetBarsSeen(barsNow)
    ns.Headers.EndDraw()
    ns.Sections.EndAdopt()
    ns.Motion.DropUndrawn(drawn.quests)
    ns.Sections.DropUndrawn(drawn.entries)
    ns.Motion.FlashHidden(function(id)
        return Tracker.HeaderOf(id, drawn)
    end, db.options.progressFlash ~= false)
    ns.Area.PlayEntered(function(id)
        return drawn.quests[id]
    end, function(id)
        return Tracker.HeaderOf(id, drawn)
    end)
    ns.Drag.Record(spans)

    -- The list is clipped at the title's lower edge, or under the search box and popups, so rows scrolling up
    -- don't show through them.
    local contentHeight = math.max(1, y + BOTTOM_PAD)
    local available = math.max(1, rootHeight - listTop - BACKGROUND_PAD)
    local visible = math.min(contentHeight, available)
    local editMode = Shared.EditMode()
    maxOffset = math.max(0, contentHeight - available)
    if renameTop then
        if renameTop < offset then
            offset = renameTop
        elseif renameBottom > offset + available then
            offset = renameBottom - available
        end
    end
    offset = math.max(0, math.min(maxOffset, offset))
    content:SetSize(width + Shared.SIDE + RIGHT_ROOM, contentHeight)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", root, "TOPLEFT", -Shared.SIDE, -listTop)
    scroll:SetSize(width + Shared.SIDE + RIGHT_ROOM, visible)
    scroll:SetVerticalScroll(offset)
    -- Only a list taller than the tracker takes the wheel, so the camera still zooms over the rest.
    scroll:EnableMouseWheel(maxOffset > 0 and not editMode)
    scroll:SetShown(#lines > 0)
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", root, "TOPLEFT", width + 3, -listTop)
        scrollBar:SetHeight(visible)
        scrollBar:SetFrameLevel(base + 21)
        scrollBar:SetShown(maxOffset > 0 and #lines > 0 and not editMode)
        scrollBar:SetScrollAllowed(not (InCombatLockdown() and Shared.isLocked()))
    end

    -- Blizzard's background is parked, so this one follows Edit Mode's opacity, 5 left of the rows, Ikar's ruling.
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", root, "TOPLEFT", -5, -timerRoom)
    background:SetPoint("BOTTOMRIGHT", root, "TOPLEFT", width + ns.Host.SCROLLBAR_ROOM + 5,
        -(listTop + (#lines > 0 and visible or 0) + BACKGROUND_PAD))
    background:SetAlpha(ns.Host.BackgroundAlpha())
    ns.Items.Sync()
end

-- An error while drawing gives Blizzard's tracker back until /kq tracker on or the next login, so no quest goes unseen.
Tracker.stats = { count = 0, total = 0, last = 0, max = 0 } -- milliseconds, for the debug panel
function Tracker.Refresh()
    local start = debugprofilestop and debugprofilestop()
    local stack
    local ok, err = xpcall(drawAll, function(e)
        stack = debugstack and debugstack(2) or debug.traceback()
        return e
    end)
    if start then
        local stats, ms = Tracker.stats, debugprofilestop() - start
        stats.count, stats.total, stats.last, stats.max = stats.count + 1, stats.total + ms, ms, math.max(stats.max, ms)
    end
    if not ok then
        Tracker.failed = err
        ns.Debug.Error(err, stack)
        ns.SafeCall(Tracker.SetEnabled, false)
        print("|cffff5555" .. ns.TITLE .. " :|r " .. L.TRACKER_FAILED)
    end
end

-- The nearest drawn header above a quest that isn't drawn itself: its closed group, else its closed category bar,
-- else Journal's or Suivi's bar. nil when its row is drawn or nothing above it is.
function Tracker.HeaderOf(id, drawn)
    if drawn.quests[id] then
        return nil
    end
    local g = ns.model:GroupOf(id)
    if g then
        return drawn.groups["g" .. g.id] or drawn.bars.mine
    end
    local q = lastQuests[id]
    if not q then
        return nil
    end
    return drawn.groups["h" .. ns.Tree.HeaderName(q)] or drawn.bars[q.category] or drawn.bars.journal
end

-- Starting and stopping --------------------------------------------------------------------------------------

local function hookOnce()
    if hooksDone then
        return
    end
    hooksDone = true
    local manager = ObjectiveTrackerManager
    if manager then
        -- Edit Mode's text size and opacity reach the rows through Blizzard's font objects and this redraw.
        if type(manager.SetTextSize) == "function" then
            hooksecurefunc(manager, "SetTextSize", function(_, size)
                ns.Fonts.NoteEditMode(size)
                ns.RequestRefresh()
            end)
        end
        if type(manager.SetOpacity) == "function" then
            hooksecurefunc(manager, "SetOpacity", ns.RequestRefresh)
        end
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            Shared.SetEditMode(true)
            ns.Drag.Cancel()
            ns.RequestRefresh()
        end, Tracker)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            Shared.SetEditMode(false)
            ns.RequestRefresh()
        end, Tracker)
    end
    for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "SUPER_TRACKING_CHANGED", "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_MONEY", "GROUP_ROSTER_UPDATE", "UNIT_QUEST_LOG_CHANGED",
        "QUEST_AUTOCOMPLETE", "QUEST_POI_UPDATE" }) do
        ns.On(event, ns.RequestRefresh)
    end
    ns.Sections.Watch()
    -- The world map's quest objectives switch shows or hides the map buttons.
    ns.On("CVAR_UPDATE", function(_, name)
        if type(name) == "string" and name:lower() == "questpoi" then
            ns.RequestRefresh()
        end
    end)
    ns.On("QUEST_DATA_LOAD_RESULT", function(_, questID)
        ns.Filter.RewardsLoaded(questID)
        ns.RequestRefresh()
    end)
    -- A new quest's row glows in, or its closed header does. One accepted in combat waits for the fight's end.
    ns.On("QUEST_ACCEPTED", function(_, questID)
        if type(questID) ~= "number" then
            return
        end
        if InCombatLockdown() then
            heldBack[questID] = true
        else
            ns.Motion.Accepted(questID)
        end
        ns.RequestRefresh()
    end)
    -- A quest leaving the log keeps its place while it fades. Either event can come first.
    ns.On("QUEST_TURNED_IN", function(_, questID)
        ns.Motion.Leave(questID, "turnin", snapshot(questID))
    end)
    ns.On("QUEST_REMOVED", function(_, questID)
        ns.Motion.Leave(questID, "remove", snapshot(questID))
    end)
    -- After the next frame's settle, so a quest a map button just tracked is found in its group.
    ns.On("SUPER_TRACKING_CHANGED", function()
        if active then
            ns.Later("focus", ns.Lock.OpenFocused)
        end
    end)
    -- Each fight starts locked; once it ends, the player's own choice is back, rows held meanwhile change, and a
    -- focus held meanwhile opens.
    ns.On("PLAYER_REGEN_DISABLED", function()
        ns.Lock.FightStarted()
        ns.Drag.Cancel()
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        for id in pairs(heldBack) do
            ns.Motion.Accepted(id)
        end
        wipe(heldBack)
        ns.Motion.CombatEnded()
        ns.Lock.FightEnded()
    end)
end

-- On: Blizzard's sections are parked and the addon's rows show. Off: Blizzard's tracker comes back as it was.
function Tracker.SetEnabled(on)
    if not ns.Host.Available() then
        return
    end
    if on then
        if not root then
            build()
        end
        Tracker.failed = nil
        hookOnce()
        ns.Host.Park(layout.width)
        -- What changed while Blizzard's tracker showed was shown there, so nothing of it replays here.
        if not active then
            ns.Motion.Reset()
            ns.Sections.Reset()
            ns.Rows.SetEntriesSeen(nil)
            ns.Headers.SetBarsSeen(nil)
            wipe(heldBack)
        end
        active = true
        hadPosition = nil
        ns.Host.Follow(root)
        ns.Host.Place(root)
        Tracker.Refresh()
    elseif active then
        ns.Headers.FinishRename(false)
        ns.Drag.Cancel()
        active = false
        root:Hide()
        ns.Sections.ReleaseAdopted()
        ns.Items.Sync()
        ns.Host.Unpark()
    end
    ns.Area.Apply()
end

function Tracker.Start()
    ns.Refresh = Tracker.Refresh
    ns.Lock.NoteFocus()
    Tracker.SetEnabled(ns.db.options.tracker ~= false)
    ns.Coverage.Start()
end
