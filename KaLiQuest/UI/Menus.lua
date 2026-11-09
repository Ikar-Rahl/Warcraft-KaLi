-- What the tracker's clicks and menus do: opening and closing, groups and tracking, the quest's details, the quest,
-- group, bar and gear menus, and deleting a group.
local _, ns = ...
local L = ns.L
local Tracker = ns.Tracker
local Shared = Tracker.Shared
local guarded, refuse, button, menu = Shared.guarded, Shared.refuse, Shared.button, Shared.menu

local Menus = {}
ns.Menus = Menus

-- Opening and closing ----------------------------------------------------------------------------------------

-- A header is saved by its key when it has one, and the text an older version saved goes with the change.
function Menus.SetGroupOpen(line, value)
    local open = ns.db.open
    if line.group then
        open.groups[line.group.id] = value or nil
    elseif line.headerKey then
        open.headers[line.headerKey] = value or nil
        open.headers[line.name] = nil
    else
        open.headers[line.name] = value or nil
    end
end
local setGroupOpen = Menus.SetGroupOpen

local function categoryOf(id)
    for _, cat in ipairs(Tracker.tree or {}) do
        if cat.id == id then
            return cat
        end
    end
end

-- The eye's effect: this group opens, every other group closes.
function Menus.OpenOnly(line)
    local open = ns.db.open
    wipe(open.groups)
    wipe(open.headers)
    setGroupOpen(line, true)
    open.categories[line.cat] = true
    if line.cat ~= "mine" then
        open.categories.journal = true
    end
    Shared.playToggle()
    ns.RequestRefresh()
end

-- The eye, and Fermer les autres.
function Menus.FocusGroup(line)
    if Shared.refusedByLock() then
        return
    end
    Menus.OpenOnly(line)
end

-- Tout ouvrir and Tout fermer on a bar: every group under it.
local function setAllUnder(barID, value)
    if Shared.refusedByLock() then
        return
    end
    local open = ns.db.open
    local cats = {}
    if barID == "journal" then
        for i = 2, #(Tracker.tree or {}) do
            cats[#cats + 1] = Tracker.tree[i]
            open.categories[Tracker.tree[i].id] = value or nil
        end
    else
        cats[1] = categoryOf(barID)
    end
    open.categories[barID] = true
    for _, cat in ipairs(cats) do
        for _, g in ipairs(cat.groups) do
            setGroupOpen({ group = g.group, name = g.name, headerKey = g.headerKey }, value)
        end
    end
    ns.RequestRefresh()
end

-- A focused quest's group, or its section and header in Journal.
function Menus.OpenParents(id)
    if not ns.Tracking.World:HasQuest(id) then
        return
    end
    local open = ns.db.open
    local g = ns.model:GroupOf(id)
    if g then
        open.categories.mine = true
        open.groups[g.id] = true
    else
        local q = ns.QuestLog.Read(ns.categories.Classify)[id]
        if not q then
            return
        end
        open.categories.journal = true
        open.categories[q.category] = true
        open.headers[q.headerKey or ns.Tree.HeaderName(q)] = true
    end
    ns.RequestRefresh()
end

-- Groups and tracking ---------------------------------------------------------------------------------------

-- A new group, named in place, with the quest or quests in it if any are given.
function Menus.NewGroup(questIDs)
    local g, reason = ns.model:CreateGroup(L.NEW_GROUP)
    if not g then
        refuse(reason)
        return
    end
    if type(questIDs) == "table" then
        ns.model:MoveQuests(questIDs, g.id)
    elseif questIDs then
        ns.model:MoveQuest(questIDs, g.id)
    end
    ns.Headers.StartRename(g.id)
end
Shared.newGroup = Menus.NewGroup

function Menus.MoveTo(questID, groupID)
    local ok, reason = ns.model:MoveQuest(questID, groupID)
    if not ok then
        refuse(reason)
    end
    ns.RequestRefresh()
end

function Menus.MoveAll(ids, groupID)
    local ok, reason = ns.model:MoveQuests(ids, groupID)
    if not ok then
        refuse(reason)
    end
    ns.RequestRefresh()
end

function Menus.TrackAll(ids)
    for _, id in ipairs(ids) do
        local ok, reason = ns.model:Track(id)
        if not ok then
            refuse(reason)
            break
        end
    end
    ns.RequestRefresh()
end

function Menus.ToggleTracking(questID)
    local ok, reason
    if ns.model:GroupOf(questID) then
        ok, reason = ns.model:MoveQuest(questID, nil)
    else
        ok, reason = ns.model:Track(questID)
    end
    if not ok then
        refuse(reason)
    end
    ns.RequestRefresh()
end

-- The game's quest windows can't open in combat from an addon, so the click says why instead of failing.
local function openMap(q)
    if InCombatLockdown() then
        refuse("combat")
    elseif QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(q.id)
    end
end

local function toggleQuestDetails(q)
    if InCombatLockdown() then
        refuse("combat")
    elseif QuestUtil and QuestUtil.OpenQuestDetails then
        QuestUtil.OpenQuestDetails(q.id)
    end
end

-- A row's click: the turn-in of a complete auto-complete quest, its popup gone, otherwise the map, as Blizzard's.
function Menus.OpenDetails(q)
    if q.isAutoComplete and q.complete and ShowQuestComplete and not InCombatLockdown() then
        if RemoveAutoQuestPopUp then
            RemoveAutoQuestPopUp(q.id)
        end
        ShowQuestComplete(q.id)
        ns.RequestRefresh()
    else
        openMap(q)
    end
end

-- Menus ------------------------------------------------------------------------------------------------------

function Menus.Quest(owner, q)
    menu(owner, function(description)
        -- Blizzard's tag, so entries other addons add to the tracker's menu appear here too.
        description:SetTag("MENU_QUEST_OBJECTIVE_TRACKER", { questID = q.id })
        description:CreateTitle(q.title)
        if C_SuperTrack then
            local focused = C_SuperTrack.GetSuperTrackedQuestID() == q.id
            button(description, focused and ns.G("STOP_SUPER_TRACK_QUEST", "Supprimer le marquage") or ns.G("SUPER_TRACK_QUEST", "Focalisation"), function()
                C_SuperTrack.SetSuperTrackedQuestID(focused and 0 or q.id)
            end)
        end
        if QuestUtil and QuestUtil.OpenQuestDetails then
            local showing = QuestUtil.IsShowingQuestDetails and QuestUtil.IsShowingQuestDetails(q.id)
            button(description, showing and ns.G("OBJECTIVES_HIDE_VIEW_IN_QUESTLOG", "Masquer les détails de la quête")
                or ns.G("OBJECTIVES_VIEW_IN_QUESTLOG", "Ouvrir les détails de la quête"), function()
                toggleQuestDetails(q)
            end)
        end
        button(description, ns.G("OBJECTIVES_SHOW_QUEST_MAP", "Ouvrir la carte des quêtes"), function()
            openMap(q)
        end)
        local current = ns.model:GroupOf(q.id)
        local move = description:CreateButton(L.MOVE_TO)
        for _, g in ipairs(ns.db.groups) do
            move:CreateRadio(g.name, function()
                return current == g
            end, guarded(function()
                -- Its own group, the ticked one, leaves it where it is.
                if ns.model:GroupOf(q.id) ~= g then
                    Menus.MoveTo(q.id, g.id)
                end
                -- A radio keeps its menu open by default; a move is done once chosen.
                return MenuResponse and MenuResponse.CloseAll
            end))
        end
        if #ns.db.groups > 0 then
            move:CreateDivider()
        end
        button(move, L.NEW_GROUP, function()
            Menus.NewGroup(q.id)
        end)
        if current then
            if ns.Tracking.World:CanRemoveWatch() then
                button(description, ns.G("OBJECTIVES_STOP_TRACKING", "Arrêter le suivi"), function()
                    Menus.MoveTo(q.id, nil)
                end)
            end
        else
            button(description, ns.G("TRACK_QUEST", "Suivre quête"), function()
                Menus.ToggleTracking(q.id)
            end)
        end
        if IsInGroup() and C_QuestLog.IsPushableQuest(q.id) and QuestUtil and QuestUtil.ShareQuest then
            button(description, ns.G("SHARE_QUEST", "Partage de quête"), function()
                QuestUtil.ShareQuest(q.id)
            end)
        end
        if QuestMapQuestOptions_AbandonQuest then
            button(description, ns.G("ABANDON_QUEST_ABBREV", "Abandon"), function()
                QuestMapQuestOptions_AbandonQuest(q.id)
            end)
        end
    end)
end

-- A picked row's menu while several are picked: what makes sense for them all, in the order they show. No abandon:
-- the game asks about each quest on its own.
function Menus.Picked(owner, ids)
    menu(owner, function(description)
        description:CreateTitle(string.format(L.PICKED, #ids))
        local move = description:CreateButton(L.MOVE_TO)
        for _, g in ipairs(ns.db.groups) do
            button(move, g.name, function()
                Menus.MoveAll(ids, g.id)
            end)
        end
        if #ns.db.groups > 0 then
            move:CreateDivider()
        end
        button(move, L.NEW_GROUP, function()
            Menus.NewGroup(ids)
        end)
        local tracked, loose, shareable = {}, {}, {}
        for _, id in ipairs(ids) do
            if ns.model:GroupOf(id) then
                tracked[#tracked + 1] = id
            else
                loose[#loose + 1] = id
            end
            if IsInGroup() and C_QuestLog.IsPushableQuest(id) then
                shareable[#shareable + 1] = id
            end
        end
        if #loose > 0 then
            button(description, L.TRACK_PICKED, function()
                Menus.TrackAll(loose)
            end)
        end
        if #tracked > 0 and ns.Tracking.World:CanRemoveWatch() then
            button(description, ns.G("OBJECTIVES_STOP_TRACKING", "Arrêter le suivi"), function()
                Menus.MoveAll(tracked, nil)
            end)
        end
        if #shareable > 0 and QuestUtil and QuestUtil.ShareQuest then
            button(description, L.SHARE_PICKED, function()
                for _, id in ipairs(shareable) do
                    QuestUtil.ShareQuest(id)
                end
            end)
        end
        description:CreateDivider()
        button(description, L.UNPICK, function()
            ns.Rows.ClearPicked()
        end)
    end)
end

local function deleteGroup(id)
    local ok, reason = ns.model:DeleteGroup(id)
    if not ok then
        refuse(reason)
    end
    ns.RequestRefresh()
end

-- A group holding quests asks first. The gear's undo covers the rest. Quests left out of the log keep their place
-- in it, for when they're accepted again, but aren't shown, so they don't count.
local function askDelete(group)
    if InCombatLockdown() then
        refuse("combat")
        return
    end
    local shown = 0
    for _, q in ipairs(group.quests) do
        if ns.Tracking.World:HasQuest(q) then
            shown = shown + 1
        end
    end
    if shown == 0 or not (StaticPopupDialogs and StaticPopup_Show) then
        deleteGroup(group.id)
        return
    end
    StaticPopupDialogs.KALIQUEST_DELETE_GROUP = StaticPopupDialogs.KALIQUEST_DELETE_GROUP or {
        text = L.DELETE_CONFIRM,
        button1 = ns.G("ACCEPT", "Accepter"),
        button2 = ns.G("CANCEL", "Annuler"),
        OnAccept = function(_, id)
            ns.SafeCall(deleteGroup, id)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("KALIQUEST_DELETE_GROUP", group.name, nil, group.id)
end

function Menus.Group(owner, line)
    menu(owner, function(description)
        description:CreateTitle(line.name)
        if line.group then
            button(description, L.RENAME, function()
                ns.Headers.StartRename(line.group.id)
            end)
            button(description, L.NEW_GROUP, function()
                Menus.NewGroup()
            end)
        end
        button(description, L.CLOSE_OTHERS, function()
            Menus.FocusGroup(line)
        end)
        if line.group then
            description:CreateDivider()
            button(description, L.DELETE_GROUP, function()
                askDelete(line.group)
            end)
        end
    end)
end

function Menus.Bar(owner, line)
    menu(owner, function(description)
        description:CreateTitle(ns.CategoryName(line.id))
        -- Recipes and achievements hold no groups to open or close.
        if line.extra then
            return
        end
        if line.id == "mine" then
            button(description, L.NEW_GROUP, function()
                Menus.NewGroup()
            end)
        end
        button(description, L.OPEN_ALL, function()
            setAllUnder(line.id, true)
        end)
        button(description, L.CLOSE_ALL, function()
            setAllUnder(line.id, false)
        end)
    end)
end

function Menus.Gear(owner)
    if InCombatLockdown() then
        refuse("combat")
        return
    end
    menu(owner, function(description)
        local deleted = ns.model.deleted
        if deleted then
            button(description, string.format(L.UNDO_DELETE, deleted.group.name), function()
                local ok, reason = ns.model:UndoDelete()
                if not ok then
                    refuse(reason)
                end
                ns.RequestRefresh()
            end)
            description:CreateDivider()
        end
        description:CreateCheckbox(ns.G("AUTO_QUEST_WATCH_TEXT", "Suivi automatique de quête"), function()
            return ns.db.options.autoQuestWatch == true
        end, guarded(function()
            ns.Tracking.SetAutoQuestWatch(not ns.db.options.autoQuestWatch)
        end))
        description:CreateCheckbox(L.GLOW, function()
            return ns.db.options.progressFlash ~= false
        end, guarded(function()
            ns.db.options.progressFlash = ns.db.options.progressFlash == false
        end))
        description:CreateCheckbox(L.AREA_HIGHLIGHT, function()
            return ns.db.options.areaHighlight ~= false
        end, guarded(function()
            ns.db.options.areaHighlight = ns.db.options.areaHighlight == false
            ns.Area.Apply()
        end))
        description:CreateDivider()
        button(description, L.OPTIONS, function()
            ns.Options.Open()
        end)
        button(description, L.DIAG_TITLE, function()
            ns.DebugPanel.Open()
        end)
        button(description, L.REPORT_TITLE, function()
            ns.Report.Open()
        end)
    end)
end
