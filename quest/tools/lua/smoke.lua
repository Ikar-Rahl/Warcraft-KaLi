-- Starts KaLi Quest and its probe on the fake API, the way the game does, and runs every slash command.
-- Run by quest/tools/run_tests.py after both addons' files are loaded. Returns a list of failures.
local F = FakeWoW
local failures = {}
local function expect(ok, what)
    if not ok then
        failures[#failures + 1] = what
    end
end
-- Scroll positions go through the scrollbar's percentages, so they can be a rounding off.
local function near(a, b)
    return math.abs(a - b) < 0.01
end

local function header(title)
    return { isHeader = true, title = title }
end
local function quest(id, title, extra)
    local row = { questID = id, title = title, level = 10, difficultyLevel = 10, suggestedGroup = 0, frequency = 0, isHeader = false }
    for k, v in pairs(extra or {}) do
        row[k] = v
    end
    return row
end
local function removeFromLog(id)
    for i = #F.entries, 1, -1 do
        if F.entries[i].questID == id and not F.entries[i].isHeader then
            table.remove(F.entries, i)
        end
    end
end
local function list(g)
    return g and table.concat(g.quests, ",") or "-"
end
local function printed(text)
    for _, line in ipairs(F.printed) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

-- Login, first run. The log reads empty at first, and the game tracks quest 9 before it fills.
F.SetLog({})
F.Fire("ADDON_LOADED", "KaLiQuest")
F.Fire("ADDON_LOADED", "KaLiQuest_Probe")
expect(KaLiQuestCharDB and KaLiQuestCharDB.version == 1, "saved data created at version 1")
expect(KaLiQuestDevDB and KaLiQuestDevDB.log, "debug data created")
F.Fire("PLAYER_LOGIN")
local db = KaLiQuestCharDB
F.watched[9] = true
F.Fire("QUEST_WATCH_LIST_CHANGED")
F.RunTimers()
expect(#db.groups == 0, "nothing is placed before the log has been read")
-- The game's own copy of its settings arrives after login and puts auto-tracking back on.
F.cvars.autoQuestWatch = "1"
F.Fire("VARIABLES_LOADED")
F.SetLog({
    header("Marche de l'Ouest"), quest(12, "La milice du peuple"), quest(9, "Les champs de mort"),
    header("Les Mortemines"), quest(214, "Les masques rouges en soie", { item = 5000 }),
    header("Forgeron"), quest(1579, "Rouages"),
})
F.Fire("PLAYER_ENTERING_WORLD", true, false)
F.Fire("QUEST_LOG_UPDATE")
F.RunTimers()
expect(F.cvars.autoQuestWatch == "0", "auto-tracking off at install, again after the game's copy arrived")
expect(db.autoQuestWatchOriginal == "1", "the game's own value is remembered")
expect(#db.groups == 1 and db.groups[1].name == "Quêtes" and list(db.groups[1]) == "9", "the tracked quest went into Quêtes")

-- Tracking from outside the addon, as the quest log's checkbox would, two in one frame.
C_QuestLog.AddQuestWatch(12)
C_QuestLog.AddQuestWatch(1579)
F.RunTimers()
expect(list(db.groups[1]) == "9,12,1579", "quests tracked elsewhere in one frame all join the top group")
C_QuestLog.RemoveQuestWatch(12)
C_QuestLog.RemoveQuestWatch(1579)
F.RunTimers()
expect(list(db.groups[1]) == "9", "and all leave it when untracked")

-- A change during combat waits for the fight to end.
F.combat = true
C_QuestLog.AddQuestWatch(12)
F.RunTimers()
expect(list(db.groups[1]) == "9", "a change in combat waits")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()
expect(list(db.groups[1]) == "9,12", "and is followed once combat ends")
C_QuestLog.RemoveQuestWatch(12)
F.RunTimers()

-- Every command, so none throws.
KaLiQuestDevDB.debug = true
KaLiQuestDevDB.events = true
for _, cmd in ipairs({ "", "status", "groups", "tree", "dump 9", "dump", "group new Donjons", "move 214 2", "move 99999 2",
    "group rename 2 Instances", "group del 2", "group undo", "group undo", "move 214 0", "autotrack on", "autotrack off",
    "debug events", "debug chat", "debug off", "log", "errors", "clear", "nonsense" }) do
    SlashCmdList.KALIQUEST(cmd)
end
F.RunTimers()
expect(db.groups[2] and db.groups[2].name == "Instances" and #db.groups[2].quests == 0, "group commands worked")
expect(not F.watched[214], "move 0 untracked the quest")
expect(printed("99999 n'est pas dans votre journal"), "moving a quest that isn't in the log is refused")
expect(printed("/kq dump <quête>"), "dump without a quest says how to use it")

-- A change made outside the addon becomes the choice; the addon's own switch still works after.
SetCVar("autoQuestWatch", "1")
expect(db.options.autoQuestWatch == true, "auto-tracking turned on with /console becomes the choice")
SlashCmdList.KALIQUEST("autotrack off")
expect(F.cvars.autoQuestWatch == "0" and db.options.autoQuestWatch == false, "and /kq autotrack off still turns it off")

-- Where the game refuses untracking, taking a quest out is refused too.
F.npe = true
SlashCmdList.KALIQUEST("move 9 0")
expect(list(db.groups[1]) == "9" and F.watched[9], "taking out is refused in the New Player Experience")
F.npe = false

-- A follow-up from the NPC who took a placed quest takes its slot.
F.npc = "Creature-0-0-0-0-237-0"
F.questID = 9
F.Fire("QUEST_COMPLETE")
removeFromLog(9)
C_QuestLog.RemoveQuestWatch(9)
F.Fire("QUEST_TURNED_IN", 9, 100, 0)
F.RunTimers()
expect(list(db.groups[1]) == "", "a turned-in quest leaves its group")
F.questID = 300
F.Fire("QUEST_DETAIL")
table.insert(F.entries, 3, quest(300, "La suite"))
F.Fire("QUEST_ACCEPTED", 300)
F.RunTimers()
expect(list(db.groups[1]) == "300" and F.watched[300], "the follow-up took its slot and is tracked")
F.npc, F.questID = nil, 0

-- A daily is remembered as repeating while it's in the log.
F.entries[#F.entries + 1] = quest(400, "Quotidienne", { frequency = 1 })
F.Fire("QUEST_ACCEPTED", 400)
F.RunTimers()
expect(db.repeatable[400] == true, "a daily in the log is remembered as repeating")

F.combat = true
SlashCmdList.KALIQUEST("group del 1")
expect(#db.groups == 2, "deleting is refused in combat")
F.combat = false

-- The tracker: Blizzard's sections parked, rows drawn from the log, and their clicks and menus.
local ns = KaLiQuestDev.ns
local tracker = ns.Tracker
local function shown(poolName, test)
    for _, f in ipairs(tracker.pools[poolName].frames) do
        if f:IsShown() and test(f.line) then
            return f
        end
    end
end
local function rowOf(id)
    return shown("row", function(line)
        return line.quest.id == id
    end)
end
-- The size and look are set in Edit Mode's dialog only, since 2026-11-13 ("comme dans flare"): a row of it, and a value
-- set as its control sets it.
local function lookRow(key, marker)
    for _, section in ipairs(ns.EditPanel.handle:Sections()) do
        for _, row in ipairs(section.rows) do
            if row.key == key and (row.markers or false) == (marker or false) then
                return row
            end
        end
    end
end
local function setLook(key, value, marker)
    local row = lookRow(key, marker)
    if not row then
        error("Edit Mode's dialog has no row " .. key)
    end
    ns.EditPanel.handle:Set(row, value)
end
local function barOf(id)
    return shown("bar", function(line)
        return line.id == id
    end)
end
local function groupOf(name)
    return shown("group", function(line)
        return line.name == name
    end)
end
local function click(frame, button)
    F.RunScript(frame, "OnClick", button or "LeftButton")
    F.RunTimers()
end
local function resize(height)
    ObjectiveTrackerFrame:SetHeight(height)
    F.RunScript(ObjectiveTrackerFrame, "OnSizeChanged")
    F.RunTimers()
end
if not KaLiQuestTracker then
    error("the tracker wasn't built: " .. table.concat(F.errors, " | "))
end
expect(#F.templateErrors == 0,
    "no Blizzard template's own setup code errors on the addon's frames: " .. table.concat(F.templateErrors, " | "))
expect(tracker.frames.background.template == nil and tracker.frames.background.nineSliceLayout == "UniqueCornersLayout",
    "the background is a plain frame given its nine-slice art, as NineSlicePanelTemplate's OnLoad needs a parent")
expect(CreateFrame("Button"):IsMouseEnabled() and not CreateFrame("Frame"):IsMouseEnabled(),
    "fake: a button takes the mouse from the start")
expect(select(2, KaLiQuestTracker:GetPoint()) == KaLiQuestHolder and select(2, KaLiQuestHolder:GetPoint()) == RightManagedFrameContainer,
    "the rows sit on the tracker's own frame, which, with a host never shown since login, tops the right-hand container")
ObjectiveTrackerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -200)
ns.Host.Place(KaLiQuestTracker)
do
    local stand = select(2, KaLiQuestHolder:GetPoint())
    local point, rel, relPoint, x, y = stand:GetPoint()
    expect(stand ~= ObjectiveTrackerFrame and stand ~= RightManagedFrameContainer and stand:IsShown() and point == "TOPRIGHT"
        and rel == UIParent and relPoint == "TOPRIGHT" and x == -80 and y == -200,
        "one moved in Edit Mode already has its anchors, so a shown stand-in on them places the rows")
end
ObjectiveTrackerFrame:ClearAllPoints()
ObjectiveTrackerFrame.top = 900
F.entries[2].objectives = { { text = "Fermiers : 2/5", finished = false }, { text = "Gnolls : 10/10", finished = true } }
ns.RequestRefresh()
F.RunTimers()
expect(select(2, KaLiQuestHolder:GetPoint()) == ObjectiveTrackerFrame and select(1, KaLiQuestHolder:GetPoint()) == "TOPLEFT",
    "once it has one, the frame hangs from its top left")
expect(tracker.IsActive() and ns.Host.IsParked(), "the tracker is on and Blizzard's sections are parked")
expect(ObjectiveTrackerManager:GetContainerForModule(QuestObjectiveTracker) == ObjectiveTrackerFrame, "Blizzard's setup ran after login")
expect(QuestObjectiveTracker:GetParent() ~= ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header:GetParent() ~= ObjectiveTrackerFrame,
    "Blizzard's title and quest section stay out of sight after its setup put the section in the host")
expect(KaLiQuestTracker:IsShown() and KaLiQuestTracker:GetParent() == ObjectiveTrackerFrame, "the rows hang from the host while it shows")
ObjectiveTrackerFrame:Hide()
expect(KaLiQuestTracker:GetParent() == UIParent, "and from UIParent while Blizzard hides it")
ObjectiveTrackerFrame:Show()
expect(tracker.lines[1].kind == "bar" and tracker.lines[1].id == "mine", "Suivi comes first")

db.open.categories.mine = nil
ns.RequestRefresh()
F.RunTimers()
click(barOf("mine"))
expect(db.open.categories.mine and groupOf("Quêtes"), "clicking Suivi opens it and shows its groups")
db.open.groups[db.groups[1].id] = true
db.open.categories.world = true
db.open.headers["Marche de l'Ouest"] = true
ns.RequestRefresh()
F.RunTimers()
local row = rowOf(12)
expect(row ~= nil and row.id == 12, "a Journal quest has a row, with the id other addons' hooks read")
expect(row and row:GetHitRectInsets() < 0, "the whole box takes clicks, badge and background margins included")
expect(row and row.Badge.atlas == "ui-hud-nameplates-levelindicator", "the level sits on Forever's nameplate level art")
click(row)
expect(F.opened == 12, "a click opens the quest's details")
F.modifier = "QUESTWATCHTOGGLE"
click(rowOf(12))
F.modifier = nil
expect(ns.model:GroupOf(12) == db.groups[1] and F.watched[12], "shift-click tracks it into the top group")
expect(shown("moved", function(line)
    return line.quest.id == 12
end), "and leaves a moved line in its section")
F.combat = true
F.opened = nil
click(rowOf(12))
expect(F.opened == nil and #F.uiErrors > 0, "in combat, details are refused with the game's message")
F.combat = false

click(rowOf(12), "RightButton")
F.MenuItem("Ouvrir les détails de la quête").choose()
expect(F.details == 12, "the menu opens the quest's details window, as Blizzard's")
local entry12 = F.entries[C_QuestLog.GetLogIndexForQuestID(12)]
entry12.complete, entry12.isAutoComplete = true, true
ns.RequestRefresh()
F.RunTimers()
row = rowOf(12)
expect(row.lines[1].Check:IsShown() and row.lines[1].Text:GetText() ~= "Quête terminée", "a quest completing keeps its lines, checked, a moment")
F.Advance(1.2)
ns.RequestRefresh()
F.RunTimers()
row = rowOf(12)
expect(row.lines[1].Text:GetText() == "Quête terminée" and row.lines[1].Dash:GetAlpha() == 1, "a complete auto-complete quest says so, with Blizzard's dash")
click(row)
expect(F.shownComplete == 12, "clicking it opens the turn-in")
click(rowOf(12), "RightButton")
F.MenuItem("Ouvrir la carte des quêtes").choose()
expect(F.opened == 12, "while the menu's map entry opens the map")
entry12.complete, entry12.isAutoComplete = nil, nil
entry12.requiredMoney, F.money = 500, 120
ns.RequestRefresh()
F.RunTimers()
row = rowOf(12)
expect(row.lines[row.shownLines].Text:GetText() == "120c / 500c", "money a quest needs shows as Blizzard's does")
F.money = 600
F.Fire("PLAYER_MONEY")
F.RunTimers()
expect(rowOf(12).shownLines == 2, "and goes once there's enough")
entry12.requiredMoney, F.money = nil, 0

local openTo = QuestMapFrame_OpenToQuestDetails
QuestMapFrame_OpenToQuestDetails = function()
    error("smoke: a failing click")
end
click(rowOf(12))
QuestMapFrame_OpenToQuestDetails = openTo
local caught
for msg in pairs(KaLiQuestDevDB.errors) do
    if msg:find("smoke: a failing click", 1, true) then
        caught = msg
    end
end
expect(caught, "an error in a click reaches /kq errors")
if caught then
    KaLiQuestDevDB.errors[caught] = nil
    for i = #F.errors, 1, -1 do
        if F.errors[i]:find("smoke: a failing click", 1, true) then
            table.remove(F.errors, i)
        end
    end
end

db.open.groups[db.groups[1].id] = nil
C_SuperTrack.SetSuperTrackedQuestID(12)
F.Fire("SUPER_TRACKING_CHANGED")
F.RunTimers()
expect(db.open.groups[db.groups[1].id] and db.open.categories.mine, "focusing a quest opens its group")
db.open.categories.classprof, db.open.headers.Forgeron = nil, nil
C_SuperTrack.SetSuperTrackedQuestID(1579)
F.Fire("SUPER_TRACKING_CHANGED")
F.RunTimers()
expect(db.open.categories.classprof and db.open.headers.Forgeron and db.open.categories.journal, "and a Journal quest's header and section")
C_SuperTrack.SetSuperTrackedQuestID(0)
F.Fire("SUPER_TRACKING_CHANGED")
F.RunTimers()
click(rowOf(12), "RightButton")
expect(F.lastMenu and F.lastMenu.tag == "MENU_QUEST_OBJECTIVE_TRACKER" and F.lastMenu.data.questID == 12, "the quest menu has Blizzard's tag")
local groupsBefore = #db.groups
F.MenuItem("Nouveau groupe").choose()
F.RunTimers()
local newGroup = db.groups[#db.groups]
expect(#db.groups == groupsBefore + 1 and ns.model:GroupOf(12) == newGroup, "Déplacer vers > Nouveau groupe moves it into a new group")
local box = tracker.frames.renameBox
expect(box:IsShown() and box:GetText() == "Nouveau groupe", "the new group is named in place")
box:SetText("Plus tard")
F.RunScript(box, "OnEnterPressed")
F.RunTimers()
expect(newGroup.name == "Plus tard" and not box:IsShown(), "Enter saves the name")
click(groupOf("Plus tard"), "RightButton")
F.MenuItem("Renommer").choose()
F.RunTimers()
box:SetText("Jamais")
F.RunScript(box, "OnEscapePressed")
F.RunTimers()
expect(newGroup.name == "Plus tard" and not box:IsShown(), "Escape cancels")
click(groupOf("Plus tard"), "RightButton")
F.MenuItem("Renommer").choose()
F.RunTimers()
box:SetText("   ")
F.RunScript(box, "OnEnterPressed")
F.RunTimers()
expect(newGroup.name == "Plus tard", "an empty name changes nothing")
click(groupOf("Plus tard"), "RightButton")
F.MenuItem("Renommer").choose()
F.RunTimers()
box:SetText("Ensuite")
F.RunScript(box, "OnEditFocusLost")
F.RunTimers()
expect(newGroup.name == "Ensuite" and not box:IsShown(), "clicking elsewhere saves")

ns.model:CreateGroup("Vide")
ns.RequestRefresh()
F.RunTimers()
click(groupOf("Vide"), "RightButton")
F.MenuItem("Supprimer le groupe").choose()
F.RunTimers()
expect(not groupOf("Vide"), "an empty group goes at once")
click(tracker.frames.title.Gear)
F.MenuItem("Annuler la suppression de « Vide »").choose()
F.RunTimers()
expect(groupOf("Vide"), "the gear's undo redraws, even with no quest to track again")
click(groupOf("Vide"), "RightButton")
F.MenuItem("Supprimer le groupe").choose()
F.RunTimers()
do
    local gone = ns.model:CreateGroup("Abandonnées")
    ns.model:MoveQuest(99999, gone.id)
    ns.RequestRefresh()
    F.RunTimers()
    F.popup = nil
    click(groupOf("Abandonnées"), "RightButton")
    F.MenuItem("Supprimer le groupe").choose()
    F.RunTimers()
    expect(#gone.quests == 1 and not F.popup and not groupOf("Abandonnées"),
        "a group holding only quests no longer in the log goes without asking")
end

click(groupOf("Ensuite"), "RightButton")
F.MenuItem("Supprimer le groupe").choose()
F.RunTimers()
expect(F.popup and F.popup.which == "KALIQUEST_DELETE_GROUP" and ns.model:GroupOf(12), "deleting a group with quests asks first")
F.AcceptPopup()
F.RunTimers()
expect(not ns.model:GroupOf(12) and not F.watched[12], "deleting the group untracks its quest")
local leftLine = false
for _, line in ipairs(tracker.lines) do
    leftLine = leftLine or line.name == "Ensuite"
end
expect(not leftLine, "no line stays in the deleted group's place")
click(tracker.frames.title.Gear)
local undoItem = F.MenuItem("Annuler la suppression de « Ensuite »")
expect(undoItem and F.lastMenu.items[1] == undoItem and not F.MenuItem("Annuler la suppression de « Vide »"),
    "the gear's menu offers the undo first, of the last deletion only")
undoItem.choose()
F.RunTimers()
expect(ns.model:GroupOf(12) and F.watched[12] and groupOf("Ensuite"), "and its undo brings it back")
click(tracker.frames.title.Gear)
expect(not F.MenuItem("Annuler la suppression de « Ensuite »") and F.lastMenu.items[1].kind == "checkbox",
    "with nothing to undo, the menu has no undo")

click(rowOf(12), "RightButton")
F.MenuItem("Arrêter le suivi").choose()
F.RunTimers()
expect(not ns.model:GroupOf(12) and not F.watched[12], "Arrêter le suivi takes the quest out")

expect(tracker.frames.title.Min.Arrow.rotation == math.pi / 2, "collapse-all is the bars' double arrow, pointing down while open")
click(tracker.frames.title.Min)
expect(db.open.tracker == false and #tracker.lines == 0 and tracker.frames.title.Min.Arrow.rotation == 0
    and tracker.frames.title.Min.Bright.rotation == 0, "the title's button collapses everything, its arrow and hover copy then pointing left")
click(tracker.frames.title.Min)

click(groupOf("Marche de l'Ouest").Eye)
expect(db.open.headers["Marche de l'Ouest"] and not db.open.groups[db.groups[1].id], "a group's eye opens it and closes the others")
click(barOf("journal"), "RightButton")
F.MenuItem("Tout fermer").choose()
F.RunTimers()
expect(not db.open.categories.world and not db.open.headers["Marche de l'Ouest"] and db.open.categories.journal, "Tout fermer on Journal")
click(barOf("journal"), "RightButton")
F.MenuItem("Tout ouvrir").choose()
F.RunTimers()
expect(db.open.categories.world and db.open.headers["Les Mortemines"], "Tout ouvrir on Journal")
click(barOf("journal"))
expect(db.open.categories.journal == false and ns.DB.Load(db).open.categories.journal == false, "a closed Journal stays closed after a reload")
click(barOf("journal"))
expect(db.open.categories.journal == true, "and opens again")

-- In game each header has a key, its headerSortKey, and is saved under it as Blizzard's quest map saves it, so it
-- holds in any language. A header saved by its text before still opens until it's opened or closed again.
do
    local keys = { ["Marche de l'Ouest"] = 0x40000000 + 40, ["Les Mortemines"] = 0x40000000 + 1581, Forgeron = 0x20000000 + 121 }
    local function saves()
        local n = 0
        for _ in pairs(db.open.headers) do
            n = n + 1
        end
        return n
    end
    local saved = db.open.headers
    local function headerRow(title)
        for _, e in ipairs(F.entries) do
            if e.isHeader and e.title == title then
                return e
            end
        end
    end
    local smith, mines, west = headerRow("Forgeron"), headerRow("Les Mortemines"), headerRow("Marche de l'Ouest")
    for _, e in ipairs({ smith, mines, west }) do
        e.headerSortKey = keys[e.title]
    end
    -- The API check tries what the addon assumes of these keys on the log itself, in game at login and in each report.
    local looked, wrong = ns.SelfCheck.Headers()
    expect(looked == 3 and #wrong == 0, "the API check finds the log's keys as the addon assumes: " .. table.concat(wrong, " | "))
    local function problems()
        return table.concat(select(2, ns.SelfCheck.Headers()), " | ")
    end
    mines.headerSortKey, west.headerSortKey, smith.headerSortKey = keys["Marche de l'Ouest"], nil, 0x20000000 + 9999
    local text = problems()
    expect(text:find([[header "Les Mortemines": area 40 is named Marche de l'Ouest]], 1, true)
        and text:find([[header "Marche de l'Ouest": key nil is neither an area nor a QuestSort]], 1, true)
        and text:find([[header "Forgeron": QuestSort 9999 isn't in the addon's data]], 1, true),
        "it reports a key naming another place, a header with no key, and a QuestSort it doesn't know: " .. text)
    mines.headerSortKey, west.headerSortKey, smith.headerSortKey = keys["Les Mortemines"], keys["Marche de l'Ouest"], 0x20000000 + 81
    text = problems()
    expect(text == [[header "Forgeron": QuestSort 81 is named Guerrier]], "a QuestSort naming another header: " .. text)
    smith.title = "Guerrier"
    local categories = ns.categories
    ns.categories = ns.Categories.New({ locale = "frFR", classFile = "MAGE", ownClassName = "Guerrier", areaName = C_Map.GetAreaInfo })
    text = problems()
    ns.categories = categories
    expect(text == [[header "Guerrier": its key puts it in classprof/class, its name in classprof/ownclass]],
        "a header its key places otherwise than its name: " .. text)
    local locale = ns.LOCALE
    -- Italian, which has no name table (German has one since 2026-11-13).
    ns.LOCALE, smith.headerSortKey = "itIT", 0x20000000 + 82
    text = problems()
    ns.LOCALE = locale
    expect(text == [[header "Guerrier": QuestSort 82, but WARRIOR's is 81]], "and, with no name table, a class header with another class's key: " .. text)
    -- Forgeron's header in German, which the French categories in use don't hold, so only its key can place it.
    smith.title, smith.headerSortKey = "Schmiedekunst", keys.Forgeron
    db.open.headers = { ["Marche de l'Ouest"] = true }
    ns.RequestRefresh()
    F.RunTimers()
    local quests = ns.QuestLog.Read(ns.categories.Classify)
    expect(quests[214].headerKey == keys["Les Mortemines"] and quests[214].category == "instances"
        and quests[1579].category == "classprof" and quests[12].category == "world", "each quest carries its header's key, which places it")
    expect(select(2, ns.categories.Classify("Krieger", 0x20000000 + 81)) == "ownclass", "the player's class header is found by its key")
    local west = groupOf("Marche de l'Ouest")
    expect(west and west.line.open and not groupOf("Les Mortemines").line.open, "a header saved by its text still opens")
    click(west)
    expect(not groupOf("Marche de l'Ouest").line.open and saves() == 0, "closing it drops the text")
    click(groupOf("Marche de l'Ouest"))
    expect(groupOf("Marche de l'Ouest").line.open and db.open.headers[keys["Marche de l'Ouest"]] == true and saves() == 1,
        "opening it saves its key alone")
    click(barOf("journal"), "RightButton")
    F.MenuItem("Tout fermer").choose()
    F.RunTimers()
    expect(saves() == 0, "Tout fermer drops the keys")
    click(barOf("journal"), "RightButton")
    F.MenuItem("Tout ouvrir").choose()
    F.RunTimers()
    expect(db.open.headers[keys["Marche de l'Ouest"]] and db.open.headers[keys["Les Mortemines"]] and db.open.headers[keys.Forgeron]
        and not db.open.headers.Schmiedekunst, "Tout ouvrir saves them")
    db.open.headers = {}
    ns.Menus.OpenParents(1579)
    expect(db.open.headers[keys.Forgeron] and not db.open.headers.Schmiedekunst, "a focused quest's header opens by its key")
    for _, e in ipairs(F.entries) do
        e.headerSortKey = nil
    end
    smith.title = "Forgeron"
    db.open.headers = saved
    ns.RequestRefresh()
    F.RunTimers()
end

expect(db.options.height == 530, "a first run gets Ikar's default height")
-- From here the rows follow the host's height, as they do once Edit Mode's height has been changed.
db.options.height = nil
resize(200)
expect(KaLiQuestTracker:GetHeight() == 200, "a new host height reaches the rows at once")
local scrollFrame = tracker.frames.scroll
expect(scrollFrame:IsMouseWheelEnabled(), "a list taller than the tracker takes the wheel")
F.RunScript(scrollFrame, "OnMouseWheel", -1)
expect(near(scrollFrame:GetVerticalScroll(), 40), "and scrolls with it")
resize(800)
expect(not scrollFrame:IsMouseWheelEnabled() and scrollFrame:GetVerticalScroll() == 0, "one that fits leaves the wheel to the camera")
F.TriggerRegistry("EditMode.Enter")
F.RunTimers()
expect(not rowOf(12):IsMouseEnabled() and not barOf("mine"):IsMouseEnabled(), "Edit Mode's clicks go through the rows")
F.TriggerRegistry("EditMode.Exit")
F.RunTimers()
expect(rowOf(12):IsMouseEnabled(), "and come back after")

-- Edit Mode: the tracker is an Edit Mode frame of its own, with one dialog for its size and look (Ikar's choice on
-- 2026-11-13, "One dialog, FlareUI's way"). Blizzard's tracker's box is see-through and lets the mouse through.
do
    local L = ns.L
    local o = db.options
    local D = ns.DB.DEFAULTS
    local held = ns.DeepCopy(o)
    local heldPositions = ns.DeepCopy(db.editMode.positions)
    local blizzard = ObjectiveTrackerFrame.Selection
    local uiWidth, uiHeight = UIParent.width, UIParent.height
    UIParent:SetSize(1920, 1080)
    expect(blizzard:GetAlpha() == 0 and not blizzard:IsMouseEnabled(),
        "Blizzard's tracker's box is see-through and lets the mouse through while the addon draws the tracker")
    F.TriggerRegistry("EditMode.Enter")
    F.RunTimers()
    local holder = KaLiQuestHolder
    local box
    for _, child in ipairs(holder.fakeChildren or {}) do
        if child.template == "EditModeSystemSelectionTemplate" then
            box = child
        end
    end
    expect(box and box:IsShown() and box.state == "highlight", "in Edit Mode the tracker's own frame shows its box, as Blizzard's frames do")
    box = box or CreateFrame("Frame", nil, nil, "EditModeSystemSelectionTemplate")
    expect(holder:GetWidth() == (o.width + ns.Host.SCROLLBAR_ROOM) * o.zoom / 100
        and holder:GetHeight() == (o.height or ObjectiveTrackerFrame:GetHeight()),
        "its box is the rows' width with the scrollbar's room, zoomed, by the height set: "
        .. holder:GetWidth() .. " " .. holder:GetHeight())
    -- Another addon scaling Blizzard's tracker, as FlareUI's minimap does to match its width, scaled the rows hanging
    -- from it too (Ikar, 2026-11-13: in Edit Mode "it use only a quarter of it"). Now they're scaled back, and fill their
    -- box at the zoom; so does the host, and the "Temps" panel keeps the rows' size.
    ObjectiveTrackerFrame:SetScale(0.615)
    F.RunTimers()
    do
        local onScreen = KaLiQuestTracker:GetEffectiveScale() / holder:GetEffectiveScale()
        local zoom = o.zoom / 100
        expect(math.abs(onScreen - zoom) < 0.0001
            and math.abs((KaLiQuestTracker:GetWidth() + ns.Host.SCROLLBAR_ROOM) * onScreen - holder:GetWidth()) < 0.01
            and math.abs(KaLiQuestTracker:GetHeight() * onScreen - holder:GetHeight()) < 0.01
            and math.abs(ObjectiveTrackerFrame:GetWidth() * 0.615 - holder:GetWidth()) < 0.01,
            "with Blizzard's tracker scaled by another addon, the rows are scaled back and fill their box, as the host does: "
            .. onScreen .. " " .. ObjectiveTrackerFrame:GetWidth())
        if QuestTimerFrame:GetParent() == ObjectiveTrackerFrame then
            expect(math.abs(QuestTimerFrame:GetEffectiveScale() / holder:GetEffectiveScale() - zoom) < 0.0001,
                "and the \"Temps\" panel keeps the rows' size")
        end
    end
    ObjectiveTrackerFrame:SetScale(1)
    F.RunTimers()

    -- Picked: Blizzard's selected frame and its dialog let go, and the addon's dialog opens beside the tracker.
    EditModeManagerFrame:SelectSystem(CreateFrame("Frame"))
    holder.left, holder.top = 1500, 900
    F.RunScript(box, "OnMouseDown")
    local dialog = KaLiQuestEditModeDialog
    expect(box.state == "selected" and box.Label:GetText() == "KaLi Quest" and dialog and dialog:IsShown()
        and EditModeManagerFrame.selected == nil and not EditModeSystemSettingsDialog:IsShown(),
        "a click picks it: its box says its name, its dialog opens, and Blizzard's frame and dialog let go")
    if dialog then
        local point, rel, relPoint, x, y = dialog:GetPoint()
        expect(point == "TOPRIGHT" and rel == UIParent and relPoint == "BOTTOMLEFT" and x == 1490 and y == 900,
            "the dialog opens beside the tracker, on the side away from the screen's edge")
        local function rowFor(key, marker)
            for _, f in ipairs(dialog.rows) do
                if f.row.key == key and (f.row.markers or false) == (marker or false) then
                    return f
                end
            end
        end
        local function shownRows()
            local list = {}
            for _, f in ipairs(dialog.rows) do
                if f:IsShown() then
                    list[#list + 1] = f.row.key
                end
            end
            return table.concat(list, ",")
        end
        local function open(i)
            if not rowFor(dialog.sections[i].section.rows[1].key, dialog.sections[i].section.rows[1].markers):IsShown() then
                F.RunScript(dialog.sections[i], "OnClick")
            end
        end
        expect(dialog.Title:GetText() == "KaLi Quest" and #dialog.sections == 5
            and dialog.sections[1].Text:GetText() == L.EDIT_SECTION_FRAME and shownRows() == "zoom,width,height,bgOpacity",
            "one dialog, titled with the addon's name, five sections, the frame's open first: " .. shownRows())
        local short = dialog:GetHeight()
        F.RunScript(dialog.sections[2], "OnClick")
        expect(shownRows() == "opacity,opacityCombat,blockRest,blockCombat,blockHover", "one section open at a time: " .. shownRows())
        F.RunScript(dialog.sections[4], "OnClick")
        local markers = 0
        for _, f in ipairs(dialog.rows) do
            markers = markers + ((f.row.markers and f:IsShown()) and 1 or 0)
        end
        expect(markers == #ns.DB.MARKERS and dialog:GetHeight() > short, "the markers' section lists every marker, and the dialog grows to hold them")
        F.RunScript(dialog.sections[4], "OnClick")
        expect(shownRows() == "", "a click on the open bar closes it")

        open(1)
        rowFor("zoom").Slider:SetValue(150)
        rowFor("bgOpacity").Slider:SetValue(40)
        F.RunTimers()
        expect(o.zoom == 150 and KaLiQuestTracker:GetScale() == 1.5 and holder:GetWidth() == (o.width + ns.Host.SCROLLBAR_ROOM) * 1.5,
            "a zoom set there applies at once, and the frame's box grows with the rows")
        expect(o.bgOpacity == 40 and tracker.frames.background:GetAlpha() == 0.4, "the background's opacity is the addon's own now")
        expect(dialog.Revert:IsEnabled() and not dialog.ResetPosition:IsEnabled(),
            "« Annuler les modifications » once something changed, no position to reset before a move")
        F.RunScript(rowFor("zoom"), "OnEnter")
        expect(F.tooltip.lines[1] == L.OPTION_ZOOM and F.tooltip.lines[2] == L.OPTION_ZOOM_TIP, "a row's tooltip says what it does")
        F.RunScript(rowFor("zoom"), "OnLeave")
        open(3)
        local flash = rowFor("progressFlash")
        flash.Button:SetChecked(false)
        F.RunScript(flash.Button, "OnClick")
        local radios = F.MenuRadios(rowFor("markerStyle").Dropdown)
        expect(o.progressFlash == false and #radios == 3 and radios[1].selected, "a box sets its option, and the markers' style has its three values, the current one ticked")
        radios[2].pick()
        expect(o.markerStyle == "text", "and picking one sets it")
        open(4)
        local dungeon = rowFor("dungeon", true)
        dungeon.Button:SetChecked(false)
        F.RunScript(dungeon.Button, "OnClick")
        expect(o.markers.dungeon == false, "a marker's box switches it, in the markers' own table")

        -- Dragged: held by its top corner on its side of the screen, in the active layout, snapping when Edit Mode does.
        local w = holder:GetWidth()
        holder.left, holder.top = 400, 700
        F.RunScript(box, "OnDragStart")
        F.RunScript(box, "OnDragStop")
        local p = db.editMode.positions.preset1
        expect(p and p.point == "TOPLEFT" and p.x == 400 and p.y == 700 - 1080 and select(2, holder:GetPoint()) == UIParent
            and dialog.ResetPosition:IsEnabled(), "dropped on the left half, it's held by its top left, in the active layout")
        F.snap = true
        holder.left, holder.top = 6, 1075
        F.RunScript(box, "OnDragStart")
        F.RunScript(box, "OnDragStop")
        p = db.editMode.positions.preset1
        expect(p.x == 0 and p.y == 0, "with Edit Mode's snapping on, dropped near the screen's corner it lands on it: " .. p.x .. " " .. p.y)
        EditModeManagerFrame.Grid.shown = true
        holder.left, holder.top = 1365, 643
        F.RunScript(box, "OnDragStart")
        F.RunScript(box, "OnDragStop")
        p = db.editMode.positions.preset1
        expect(p.point == "TOPRIGHT" and p.x == 1360 + w - 1920 and p.y == 640 - 1080,
            "on the right half it's held by its top right, and on a grid line while the grid shows: " .. p.x .. " " .. p.y)
        F.snap, EditModeManagerFrame.Grid.shown = false, false
        holder.left, holder.top = 1360, 640
        F.RunScript(dialog, "OnKeyDown", "LEFT")
        holder.left = 1359 -- the fake doesn't move it: where the game would have it now
        F.shift = true
        F.RunScript(dialog, "OnKeyDown", "UP")
        F.shift = false
        p = db.editMode.positions.preset1
        expect(p.x == 1359 + w - 1920 and p.y == 650 - 1080, "the arrows move it 1, with Shift 10")
        F.combat = true
        holder.left, holder.top = 100, 100
        F.RunScript(box, "OnDragStart")
        F.RunScript(box, "OnDragStop")
        expect(db.editMode.positions.preset1.y == 650 - 1080, "not in a fight")
        F.combat = false

        -- Each layout its own place; one where it was never moved has it on Blizzard's tracker.
        F.editLayouts.activeLayout = 4
        F.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        expect(select(2, holder:GetPoint()) == ObjectiveTrackerFrame and not dialog.ResetPosition:IsEnabled(),
            "in another layout, never moved there, it's on Blizzard's tracker")
        holder.left, holder.top = 300, 800
        F.RunScript(box, "OnDragStart")
        F.RunScript(box, "OnDragStop")
        expect(db.editMode.positions["custom:Mine"] and db.editMode.positions.preset1, "each layout keeps its own place, the player's own by name")
        F.editLayouts.activeLayout = 1
        F.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        expect(select(2, holder:GetPoint()) == UIParent and select(4, holder:GetPoint()) == 1359 + w - 1920, "back in the first, its place there")
        F.RunScript(dialog.ResetPosition, "OnClick")
        expect(db.editMode.positions.preset1 == nil and select(2, holder:GetPoint()) == ObjectiveTrackerFrame,
            "« Revenir à la position par défaut » puts it back on Blizzard's tracker")

        -- Cancelling: back to what it was on entering Edit Mode, or at its last save.
        F.RunScript(dialog.Revert, "OnClick")
        F.RunTimers()
        expect(o.zoom == held.zoom and o.bgOpacity == held.bgOpacity and o.progressFlash == held.progressFlash
            and o.markerStyle == held.markerStyle and o.markers.dungeon == held.markers.dungeon
            and db.editMode.positions["custom:Mine"] == nil and not ns.EditPanel.HasChanges() and not dialog.Revert:IsEnabled(),
            "« Annuler les modifications » puts back the settings and places as they were on entering Edit Mode")
        open(1)
        rowFor("zoom").Slider:SetValue(120)
        F.TriggerRegistry("EditMode.SavedLayouts")
        rowFor("zoom").Slider:SetValue(130)
        F.RunScript(dialog.Revert, "OnClick")
        expect(o.zoom == 120 and rowFor("zoom").Slider.rightText == "120 %", "after Edit Mode's save, back to what was saved")
        F.RunScript(dialog.Defaults, "OnClick")
        F.RunTimers()
        expect(o.zoom == D.zoom and o.bgOpacity == D.bgOpacity and o.markerStyle == "icons" and o.progressFlash == true
            and o.markers.dungeon == true, "« Par défaut » puts every row back to its default")

        -- Letting go: a frame of Blizzard's picked, Escape, a fight, leaving Edit Mode.
        EditModeManagerFrame:SelectSystem(CreateFrame("Frame"))
        expect(box.state == "highlight" and not dialog:IsShown(), "a frame of Blizzard's picked lets go of it")
        EditModeSystemSettingsDialog:Hide()
        F.RunScript(box, "OnMouseDown")
        F.RunScript(dialog, "OnKeyDown", "ESCAPE")
        expect(not dialog:IsShown() and box.state == "highlight", "Escape closes the dialog")
        F.RunScript(box, "OnMouseDown")
        open(1)
        F.combat = true
        F.Fire("PLAYER_REGEN_DISABLED")
        expect(not rowFor("zoom").Slider:IsSliderEnabled() and not dialog.Defaults:IsEnabled(), "in a fight its rows and buttons wait")
        F.combat = false
        F.Fire("PLAYER_REGEN_ENABLED")
        expect(rowFor("zoom").Slider:IsSliderEnabled(), "and come back after")
    end
    F.TriggerRegistry("EditMode.Exit")
    F.RunTimers()
    expect(not box:IsShown() and not (dialog and dialog:IsShown()), "leaving Edit Mode hides its box and its dialog")

    -- The options page's « Mode Édition », where the size and look were (Ikar, 2026-11-13: "comme dans flare"):
    -- Blizzard's options close keeping what was set, Edit Mode opens, and the tracker is picked with its dialog open.
    local editButton
    for _, init in ipairs(F.settingsLayout.initializers) do
        if init.name == L.OPTION_EDIT_MODE then
            editButton = init
        end
    end
    expect(editButton and editButton.buttonText == "Mode Édition" and editButton.tooltip == L.OPTION_EDIT_MODE_TIP,
        "the options page has a « Mode Édition » button where the size and look were")
    if editButton then
        Settings.OpenToCategory(77)
        editButton.buttonClick()
        F.RunTimers()
        expect(not SettingsPanel:IsShown() and SettingsPanel.skippedTransition and EditModeManagerFrame:IsShown()
            and box:IsShown() and box.state == "selected" and dialog:IsShown(),
            "it closes the options, without the game menu, opens Edit Mode and picks the tracker, its dialog open")
        HideUIPanel(EditModeManagerFrame)
        F.RunTimers()
        expect(not box:IsShown() and not dialog:IsShown(), "setup: Edit Mode left")
        Settings.OpenToCategory(77)
        F.unapplied = true
        editButton.buttonClick()
        F.RunTimers()
        expect(SettingsPanel:IsShown() and F.popup and F.popup.which == "GAME_SETTINGS_CONFIRM_DISCARD"
            and not EditModeManagerFrame:IsShown(), "with a change waiting for « Appliquer », Blizzard asks first and Edit Mode waits")
        F.unapplied, F.popup = nil, nil
        SettingsPanel:Hide()
        local errorsBefore = #F.uiErrors
        F.editModeRefused = true
        editButton.buttonClick()
        F.RunTimers()
        expect(not EditModeManagerFrame:IsShown() and F.uiErrors[errorsBefore + 1] == ERROR_SLASH_EDITMODE_CANNOT_ENTER,
            "the game refusing Edit Mode, it says so with the game's own line: " .. tostring(F.uiErrors[errorsBefore + 1]))
        F.editModeRefused = nil
        F.combat = true
        editButton.buttonClick()
        F.combat = false
        F.RunTimers()
        expect(not EditModeManagerFrame:IsShown() and #F.uiErrors == errorsBefore + 2, "and not in a fight")
    end

    -- With Blizzard's tracker back, Blizzard's box is too; started again, the addon's tracker closes Blizzard's dialog.
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    expect(blizzard:GetAlpha() == 1 and blizzard:IsMouseEnabled(), "with Blizzard's tracker back, its box is back")
    EditModeManagerFrame:SelectSystem(ObjectiveTrackerFrame)
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    expect(blizzard:GetAlpha() == 0 and not EditModeSystemSettingsDialog:IsShown(), "and the addon's back, Blizzard's box goes, with its dialog")

    -- Back as they were, in the same tables: the options page's settings read the markers' own.
    for k in pairs(o) do
        if held[k] == nil then
            o[k] = nil
        end
    end
    for k, v in pairs(held) do
        if k == "markers" then
            for kind, on in pairs(v) do
                o.markers[kind] = on
            end
        else
            o[k] = v
        end
    end
    db.editMode.positions = heldPositions
    UIParent.width, UIParent.height = uiWidth, uiHeight
    ns.EditFrame.Apply()
    ns.RequestRefresh()
    F.RunTimers()
end

-- The title row's padlock and gear, quiet title buttons, tooltips, key bindings and the scrollbar.
local lock, gear, tools = tracker.frames.title.Lock, tracker.frames.title.Gear, tracker.frames.title.Tools
expect(tools:GetAlpha() == 0.5, "the title's buttons are quiet at rest")
F.RunScript(rowOf(12), "OnEnter")
expect(tools:GetAlpha() == 1, "and come up while the pointer is over the tracker")
local fired = F.triggered[#F.triggered]
expect(fired and fired.event == "OnQuestBlockHeader.OnEnter" and fired.args[2] == 12 and fired.args[3] == false,
    "hovering a row fires Blizzard's event for other addons, saying no tooltip is up")
F.RunScript(rowOf(12), "OnLeave")
F.RunTimers()
expect(tools:GetAlpha() == 0.5, "and go quiet once it has left")
F.RunScript(tracker.frames.title, "OnEnter")
expect(tools:GetAlpha() == 1, "the title row itself wakes them too")
F.RunTimers()
local groupsKept = db.groups
db.groups = {}
F.RunScript(rowOf(12), "OnEnter")
fired = F.triggered[#F.triggered]
expect(F.tooltip.lines[1] == "La milice du peuple" and F.tooltip.lines[2] == "Clic droit : Déplacer vers un groupe"
    and fired.args[3] == true, "before the first group, a row's tooltip says how to make one, and tells other addons it's up")
F.RunScript(rowOf(12), "OnLeave")
db.groups = groupsKept
F.RunTimers()
local moved300 = shown("moved", function(line)
    return line.quest.id == 300
end)
F.RunScript(moved300, "OnEnter")
expect(F.tooltip.lines[1] == "Dans le groupe « " .. db.groups[1].name .. " »", "a moved quest's line names its group")
F.RunScript(moved300, "OnLeave")

-- Holding Shift or Ctrl over a quest says what a click would then do in one plain word, Ikar's rulings: in a
-- tooltip's box at three quarters of its size and half seen, where the tooltip would be or under the one up. Grey
-- while refused.
do
    local row = rowOf(12)
    local function tip()
        return F.tooltip.shown and table.concat(F.tooltip.lines, "|") or ""
    end
    local function box()
        return ns.Tracker.Shared.hint
    end
    -- The word shown, with its colour: "Suivre (1 1 1)".
    local function word()
        local h = box()
        if not (h and h:IsShown() and h.owner) then
            return ""
        end
        return h.Text:GetText() .. " (" .. table.concat(h.Text.textColor or {}, " ") .. ")"
    end
    local function under()
        return select(2, box():GetPoint())
    end
    local function press(modifier, ctrl)
        F.modifier, F.ctrl = modifier, ctrl
        F.Fire("MODIFIER_STATE_CHANGED", ctrl and "LCTRL" or "LSHIFT", (modifier or ctrl) and 1 or 0)
    end
    F.RunScript(row, "OnEnter")
    expect(tip() == "" and word() == "", "at rest, a row shows no tooltip")
    press("QUESTWATCHTOGGLE")
    expect(word() == "Suivre (1 1 1)" and tip() == "" and under() == row,
        "holding Shift over a quest says Suivre, white, without its title, beside the row")
    expect(box().template == "TooltipBackdropTemplate" and box():GetScale() == 0.75 and box():GetAlpha() == 0.5,
        "in a tooltip's box, at three quarters of its size and half seen")
    press(nil, true)
    expect(word() == "Multisélection (1 1 1)", "holding Ctrl, Multisélection")
    click(row)
    expect(ns.Rows.IsPicked(12) and word() == "Désélectionner (1 1 1)", "once picked, that a click lets it go")
    click(row)
    press(nil, nil)
    expect(not ns.Rows.IsPicked(12) and word() == "" and tip() == "", "letting go takes the word away")
    F.chatOpen = true
    press("CHATLINK")
    expect(word() == "Insérer le lien (1 1 1)", "with chat open, that it links the quest")
    F.chatOpen = nil
    press("QUESTWATCHTOGGLE")
    F.RunScript(row, "OnDragStart", "LeftButton")
    expect(ns.Drag.Active() and word() == "", "a drag takes the word away")
    ns.Drag.Cancel()
    press(nil, nil)
    F.RunScript(row, "OnLeave")
    press("QUESTWATCHTOGGLE")
    expect(tip() == "" and word() == "", "away from the rows, a modifier shows nothing")
    press(nil, nil)
    local groupsHeld = db.groups
    db.groups = {}
    F.RunScript(row, "OnEnter")
    press("QUESTWATCHTOGGLE")
    expect(tip() == "La milice du peuple|Clic droit : Déplacer vers un groupe" and word() == "Suivre (1 1 1)"
        and under() == GameTooltip, "a row whose tooltip says something already gets the word under it")
    press(nil, nil)
    F.RunScript(row, "OnLeave")
    db.groups = groupsHeld
    F.RunScript(moved300, "OnEnter")
    press("QUESTWATCHTOGGLE")
    local inGroup = "Dans le groupe « " .. db.groups[1].name .. " »"
    expect(tip() == inGroup and word() == "Arrêter le suivi (1 1 1)" and under() == GameTooltip,
        "over a tracked quest's line, under its group, that it stops tracking it")
    F.combat = true
    press("QUESTWATCHTOGGLE")
    expect(word() == "Arrêter le suivi (0.5 0.5 0.5)", "and in a fight, greyed")
    F.combat = false
    F.RunScript(moved300, "OnLeave")
    expect(tip() == "" and word() == "", "leaving the line takes both away")
    press(nil, nil)
    row = rowOf(12)
    F.RunScript(row, "OnEnter")
    press("QUESTWATCHTOGGLE")
    click(row)
    expect(ns.model:GroupOf(12) and word() == "" and tip() == "", "a Shift-click tracks it, and the word goes with the quest")
    press(nil, nil)
    F.RunScript(row, "OnLeave")
    ns.model:MoveQuest(12, nil)
    ns.RequestRefresh()
    F.RunTimers()
    -- A player who gave Ctrl to the game's tracking click: Ctrl+click tracks, as the game's own tracker does, rather
    -- than picking.
    F.modifiedClicks.QUESTWATCHTOGGLE = "CTRL"
    row = rowOf(12)
    F.RunScript(row, "OnEnter")
    press("QUESTWATCHTOGGLE", true)
    expect(word() == "Suivre (1 1 1)", "with Ctrl the tracking key, holding it says Suivre, not Multisélection: " .. word())
    click(row)
    expect(ns.model:GroupOf(12) and not ns.Rows.IsPicked(12), "and a Ctrl+click tracks the quest rather than picking it")
    press(nil, nil)
    F.RunScript(row, "OnLeave")
    F.modifiedClicks.QUESTWATCHTOGGLE = nil
    ns.model:MoveQuest(12, nil)
    ns.RequestRefresh()
    F.RunTimers()
end

F.RunScript(lock, "OnEnter")
expect(F.tooltip.lines[1] == "Déverrouillé", "the padlock says it's open")
local pivot = lock.Shackle.rotationPoint
expect((lock.Shackle.rotation or 0) < 0 and pivot and pivot.x == 0.75 and pivot.y == 0 and not lock.Add:IsShown(),
    "unlocked, its shackle swings open on its right leg, without the bright copy")
click(lock)
expect(db.locked == true and F.tooltip.lines[1] == "Verrouillé", "clicking it locks, and its tooltip follows")
expect(lock.Shackle.rotation == 0 and lock.Add:IsShown(), "locked, the shackle is shut and a copy on top makes it bright")
F.RunScript(lock, "OnLeave")
local mineOpen, flashes = db.open.categories.mine, lock.Flash.plays or 0
click(barOf("mine"))
click(tracker.frames.title.Min)
KaLiQuest_Binding("next")
expect(db.open.categories.mine == mineOpen and db.open.tracker and (lock.Flash.plays or 0) == flashes + 3,
    "locked, bars, collapse-all and the bindings change nothing, and each try flashes the padlock")
expect(tools:GetAlpha() == 1, "a refused key binding brings the title's buttons up, so the flash shows in full")
F.RunTimers()
click(rowOf(12), "RightButton")
F.MenuItem(db.groups[1].name).choose()
expect(ns.model:GroupOf(12) == db.groups[1], "Déplacer vers still works while locked")
ns.model:MoveQuest(12, nil)
db.open.headers.Forgeron = nil
C_SuperTrack.SetSuperTrackedQuestID(1579)
F.Fire("SUPER_TRACKING_CHANGED")
F.RunTimers()
expect(not db.open.headers.Forgeron, "a focus while locked waits")
C_SuperTrack.SetSuperTrackedQuestID(0)
F.Fire("SUPER_TRACKING_CHANGED")
F.RunTimers()
click(lock)
expect(db.locked == false and not db.open.headers.Forgeron, "one removed meanwhile doesn't open once unlocked")
click(lock)
C_SuperTrack.SetSuperTrackedQuestID(1579)
F.Fire("SUPER_TRACKING_CHANGED")
F.RunTimers()
click(lock)
F.RunTimers()
expect(db.locked == false and db.open.headers.Forgeron, "one still focused opens its group once unlocked")

F.RunScript(lock, "OnEnter")
F.combat = true
F.Fire("PLAYER_REGEN_DISABLED")
F.RunTimers()
expect(F.tooltip.lines[1] == "Verrouillé en combat", "the padlock's tooltip follows the fight starting")
F.RunScript(lock, "OnLeave")
F.RunScript(gear, "OnEnter")
expect(F.tooltip.lines[2] == ERR_NOT_IN_COMBAT, "the gear's tooltip says it can't open in combat")
F.RunScript(gear, "OnLeave")
mineOpen = db.open.categories.mine
click(barOf("mine"))
expect(db.open.categories.mine == mineOpen, "combat locks the tracker")
click(lock)
click(barOf("mine"))
expect(db.locked == false and db.open.categories.mine ~= mineOpen, "the padlock unlocks it for this fight, without changing the saved choice")
click(barOf("mine"))
click(lock)
resize(200)
local scroller, bar = tracker.frames.scroll, tracker.frames.scrollBar
local before = scroller:GetVerticalScroll()
flashes = lock.Flash.plays or 0
F.RunScript(scroller, "OnMouseWheel", -1)
expect(scroller:GetVerticalScroll() == before and (lock.Flash.plays or 0) == flashes + 1,
    "locked in combat, the list doesn't scroll, and the wheel flashes the padlock")
bar:ScrollStepInDirection(1)
F.RunScript(bar.Forward, "OnMouseDown")
expect(scroller:GetVerticalScroll() == before and (lock.Flash.plays or 0) == flashes + 2, "its scrollbar's arrows don't move it either")
bar:SetScrollPercentage(1)
expect(scroller:GetVerticalScroll() == before and (lock.Flash.plays or 0) == flashes + 3, "nor does dragging its thumb")
click(lock)
bar:SetScrollPercentage(1)
local range = scroller:GetVerticalScrollRange()
expect(range > 0 and scroller:GetVerticalScroll() == range, "unlocked for the fight, it scrolls to the end")
click(lock)
flashes = lock.Flash.plays or 0
scroller.scrollChild.height = scroller.scrollChild.height - 50
F.RunTimers()
expect(near(scroller:GetVerticalScroll(), range - 50) and (lock.Flash.plays or 0) == flashes,
    "locked again, a list grown shorter ends sooner, without fighting the scrollbar or flashing")
local errorsBefore = #F.uiErrors
F.lastMenu = nil
click(gear)
expect(F.lastMenu == nil and #F.uiErrors == errorsBefore + 1, "the gear says why it can't open in combat")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()
before = scroller:GetVerticalScroll()
bar:SetAlpha(0)
F.RunScript(scroller, "OnMouseWheel", 1)
expect(near(scroller:GetVerticalScroll(), before - 40) and bar:GetAlpha() == 1, "after the fight it scrolls again, and the scrollbar shows")
F.RunTimers()
resize(800)

click(gear)
F.MenuItem("Suivi automatique de quête").choose()
expect(db.options.autoQuestWatch == true and F.cvars.autoQuestWatch == "1", "the gear's menu switches auto-tracking")
F.MenuItem("Suivi automatique de quête").choose()
expect(db.options.autoQuestWatch == false and F.cvars.autoQuestWatch == "0", "and back")
F.MenuItem("Options").choose()
expect(F.settingsOpened == 77, "and opens the addon's page in the game's options")
SettingsPanel:Hide()
click(gear)
F.MenuItem("Mode Édition").choose()
F.RunTimers()
expect(EditModeManagerFrame:IsShown() and ns.EditFrame.IsSelected() and KaLiQuestEditModeDialog:IsShown(),
    "and « Mode Édition » opens Edit Mode with the tracker picked, where its size and look are set")
HideUIPanel(EditModeManagerFrame)
F.RunTimers()
click(gear)
local gearItems = F.lastMenu and F.lastMenu.items or {}
expect(not F.MenuItem("Diagnostic") and gearItems[#gearItems - 1] and gearItems[#gearItems - 1].text == "Options",
    "the gear's menu has no Diagnostic: players report bugs, they don't diagnose (Ikar, 2026-11-11)")
ns.DebugPanel.Open()
local diagPanel = ns.DebugPanel.Frames()
expect(diagPanel and diagPanel:IsShown(), "the diagnostics panel still opens")
diagPanel:Hide()
local diagButton
for _, init in ipairs(F.settingsLayout.initializers) do
    if init.buttonText == "Ouvrir le diagnostic" then
        diagButton = init
    end
end
if diagButton then
    diagButton.buttonClick()
end
expect(diagButton and diagPanel:IsShown(), "and so does a button on the options page")
diagPanel:Hide()
F.settingsOpened = nil
SlashCmdList.KALIQUEST("options")
expect(F.settingsOpened == 77, "/kq options opens it too")
local tipsButton = F.settingsLayout.initializers[1]
expect(tipsButton and tipsButton.name == "Astuces" and tipsButton.buttonText == "Afficher", "the options page starts with a button to the tips")
F.settingsOpened = nil
tipsButton.buttonClick()
expect(F.settingsTips and F.settingsTips.parent == F.settingsCategory and F.settingsOpened == 78, "which opens their page, under the addon's")
local tipTexts = {}
for _, fs in ipairs(F.settingsTips.frame.fontStrings or {}) do
    tipTexts[#tipTexts + 1] = fs:GetText() or ""
end
tipTexts = table.concat(tipTexts, "\n")
expect(tipTexts:find("Ctrl+clic", 1, true) and tipTexts:find("Maj+clic", 1, true) and tipTexts:find("Cadenas", 1, true)
    and tipTexts:find("dans Options > Raccourcis clavier > Add-ons.", 1, true), "the tips name the shortcuts, the rules, and where to bind the keys")
F.combat = true
F.settingsOpened = nil
tipsButton.buttonClick()
expect(F.settingsOpened == nil, "the tips don't open in combat")
F.combat = false
local trackerSetting = F.settingsCategory and F.settingsCategory.settings.KALIQUEST_TRACKER
expect(trackerSetting ~= nil, "the page has the tracker switch")
trackerSetting:SetValue(false)
expect(not tracker.IsActive() and not ns.Host.IsParked(), "switching the tracker off there gives Blizzard's back")
trackerSetting:SetValue(true)
F.RunTimers()
expect(tracker.IsActive() and ns.Host.IsParked(), "and on again")

KaLiQuest_Binding("next")
expect(db.open.groups[db.groups[1].id] and not db.open.groups[db.groups[2].id] and not next(db.open.headers),
    "the next-group binding opens the first group and closes the rest")
KaLiQuest_Binding("next")
expect(db.open.groups[db.groups[2].id] and not db.open.groups[db.groups[1].id], "then the next")
KaLiQuest_Binding("previous")
KaLiQuest_Binding("previous")
expect(db.open.groups[db.groups[#db.groups].id], "and wraps round at the ends")
KaLiQuest_Binding("collapse")
expect(db.open.tracker == false, "the collapse binding collapses")
KaLiQuest_Binding("collapse")
KaLiQuest_Binding("lock")
expect(db.locked == true, "the lock binding locks")
KaLiQuest_Binding("lock")
F.RunTimers()

SlashCmdList.KALIQUEST("tracker off")
expect(not tracker.IsActive() and not ns.Host.IsParked() and QuestObjectiveTracker:GetParent() == ObjectiveTrackerFrame
    and not KaLiQuestTracker:IsShown(), "tracker off gives Blizzard its sections back")
SlashCmdList.KALIQUEST("tracker on")
F.RunTimers()
expect(tracker.IsActive() and ns.Host.IsParked() and db.options.tracker, "and on parks them again")

-- Search and filter: they only hide rows, and nothing saved changes.
local search = ns.Search.State
local function questLines()
    local ids = {}
    for _, l in ipairs(tracker.lines) do
        if l.kind == "quest" then
            ids[#ids + 1] = l.quest.id
        end
    end
    table.sort(ids)
    return table.concat(ids, ",")
end
local inLog = select(2, C_QuestLog.GetNumQuestLogEntries())
-- Rewards are searched by name: a currency, a spell, and for 12 data that loads later.
F.rewardCurrencies = { [214] = { { name = "Insigne de bravoure" } } }
F.rewardSpells = { [1579] = { [99] = "Apprentissage du rivetage" } }
F.rewardsPending = { [12] = true }
db.open.tracker = true
db.open.categories.instances = false
ns.RequestRefresh()
F.RunTimers()
click(search().searchButton)
expect(search().open and search().box:IsShown(), "the magnifying glass opens the search box")
search().box:SetText("MASQUES rouges")
F.RunScript(search().box, "OnTextChanged", true)
F.RunTimers()
expect(questLines() == "214" and rowOf(214), "a search shows only matching quests, opening the levels that hold them")
expect(db.open.categories.instances == false, "without saving those levels open")
expect(search().status:GetText() == "1 quête affichée sur " .. inLog .. " · " and search().clear:IsShown(),
    "the status line counts what shows, with Tout effacer")
expect(search().searchButton.Lit:IsShown(), "the magnifying glass is lit while searching")
search().box:SetText("1579")
F.RunScript(search().box, "OnTextChanged", true)
F.RunTimers()
expect(questLines() == "1579", "a search finds a quest by its ID")
local function searchFor(text)
    search().box:SetText(text)
    F.RunScript(search().box, "OnTextChanged", true)
    F.RunTimers()
    return questLines()
end
expect(searchFor("insigne") == "214", "a search finds a quest by a currency it rewards")
expect(searchFor("rivetage") == "1579", "and by a spell it teaches")
expect(F.loadRequests[12] == 1, "rewards not loaded yet are asked for, once")
F.rewardsPending = nil
F.rewardCurrencies[12] = { { name = "Jeton de milice" } }
F.Fire("QUEST_DATA_LOAD_RESULT", 12, true)
expect(searchFor("jeton") == "12", "and found once they load")
search().box:SetText("zzzz")
F.RunScript(search().box, "OnTextChanged", true)
F.RunTimers()
expect(questLines() == "" and search().status:GetText() == "Aucun résultat trouvé · " and search().clear:IsShown(),
    "no match says so, and can still be cleared")
click(search().clear)
expect(not search().open and search().query == "" and not search().status:IsShown() and tracker.lines[1].id == "mine",
    "Tout effacer closes the search and shows everything again")
click(search().searchButton)
F.combat = true
F.Fire("PLAYER_REGEN_DISABLED")
local linesBefore = questLines()
search().box:SetText("rouages")
F.RunScript(search().box, "OnTextChanged", true)
F.RunTimers()
expect(questLines() == linesBefore, "text typed in combat waits, so rows don't move under item buttons")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()
expect(questLines() == "1579", "and applies once the fight ends")
F.RunScript(search().box, "OnEscapePressed")
F.RunTimers()
expect(not search().open and search().query == "" and not search().box:IsShown(), "Escape closes the box and clears the search")
F.combat = true
local errorsNow = #F.uiErrors
click(search().searchButton)
expect(not search().open and #F.uiErrors == errorsNow + 1, "the search can't open in combat")
F.lastMenu = nil
click(search().filterButton)
expect(F.lastMenu == nil and #F.uiErrors == errorsNow + 2, "nor the filter")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()

click(search().filterButton)
local daily = F.MenuItem("Quotidienne (1)")
expect(daily and F.MenuItem("Non répétable (" .. (inLog - 1) .. ")"), "the filter lists the log's values, with counts")
daily.choose()
F.RunTimers()
expect(search().status:GetText() == "1 quête affichée sur " .. inLog .. " · " and search().filterButton.Lit:IsShown(),
    "ticking one hides the rest, and the filter button is lit")
do
    local mineBar, groupHeaders, journal = tracker.lines[1], 0, nil
    for _, l in ipairs(tracker.lines) do
        if l.kind == "group" and l.group then
            groupHeaders = groupHeaders + 1
        elseif l.kind == "bar" and l.id == "journal" then
            journal = l
        end
    end
    expect(mineBar.id == "mine" and mineBar.count == "0" and groupHeaders == (db.open.categories.mine and #db.groups or 0),
        "Suivi and the player's groups stay, with no match, to drag quests into")
    expect(journal and journal.count == "1", "and Journal counts its match")
end
expect(ns.DB.Load(db).filters["repeat"].daily == true, "the filter is saved")
click(search().filterButton)
F.MenuItem("Tout effacer").choose()
F.RunTimers()
expect(not next(db.filters) and not search().status:IsShown() and not search().filterButton.Lit:IsShown(), "Tout effacer clears it")
do
    click(search().searchButton)
    local before = searchFor("rouages")
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    F.RunScript(search().box, "OnEscapePressed")
    F.RunTimers()
    expect(before == "1579" and questLines() == before and not search().open, "Escape in combat closes the box, but the rows wait for the fight's end")
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    F.RunTimers()
    expect(not search().status:IsShown() and questLines() ~= before, "then the search clears")
end

-- Blizzard's popups, under the title, push the list down and open the quest when clicked.
local function listTop()
    return -select(5, tracker.frames.scroll:GetPoint())
end
local topBefore = listTop()
F.popups = { { questID = 1579, type = "COMPLETE" }, { questID = 12, type = "OFFER" } }
ns.RequestRefresh()
F.RunTimers()
local function shownPopups()
    local found = {}
    for _, f in ipairs(F.frames) do
        if f.parent == tracker.frames.fixed and f.popUpType and f:IsShown() then
            found[f.popUpType] = f
        end
    end
    return found
end
local popups = shownPopups()
expect(popups.COMPLETE and popups.OFFER and listTop() > topBefore + 2 * 68, "the game's popups show above the list, pushing it down")
expect(popups.COMPLETE.Contents.TopText:GetText() == "Cliquer pour terminer la quête" and popups.COMPLETE.Pulse.plays,
    "a complete one says so and pulses")
click(tracker.frames.title.Min)
expect(not tracker.frames.fixed:IsShown(), "collapsed, the tracker hides them, as Blizzard's")
click(tracker.frames.title.Min)
F.shownComplete = nil
popups.COMPLETE.mouseOver = true
F.combat = true
F.RunScript(popups.COMPLETE, "OnMouseUp", "LeftButton")
F.RunTimers()
expect(F.shownComplete == nil and #F.popups == 2, "in a fight a popup's click is refused, as a row's, and it stays")
F.combat = false
F.RunScript(popups.COMPLETE, "OnMouseUp", "LeftButton")
F.RunTimers()
expect(F.shownComplete == 1579 and #F.popups == 1, "clicking one opens the turn-in and takes it away")
popups = shownPopups()
popups.OFFER.mouseOver = true
F.RunScript(popups.OFFER, "OnMouseUp", "LeftButton")
F.RunTimers()
expect(F.shownOffer == 12 and #F.popups == 0 and listTop() == topBefore, "an offer opens the quest, and the list goes back up")
click(tracker.frames.title.Min)
F.combat = true
F.Fire("PLAYER_REGEN_DISABLED")
F.popups = { { questID = 1579, type = "COMPLETE" } }
ns.RequestRefresh()
F.RunTimers()
expect(not db.open.tracker, "a popup arriving in a fight leaves the collapsed tracker as it is meanwhile")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()
expect(db.open.tracker and shownPopups().COMPLETE, "then opens it to show the popup, as Blizzard's")
click(tracker.frames.title.Min)
expect(not db.open.tracker, "collapsing it again, with the same popup there, stays collapsed")
click(tracker.frames.title.Min)
F.popups = {}
ns.RequestRefresh()
F.RunTimers()

-- Quest items: a secure button over the row's slot, never moved in combat.
db.open.categories.journal, db.open.categories.instances, db.open.headers["Les Mortemines"] = true, true, true
ns.RequestRefresh()
F.RunTimers()
tracker.frames.scroll.top = 800
local row214 = rowOf(214)
row214.ItemSlot.left, row214.ItemSlot.top = 200, 790
ns.Items.Sync()
local itemButton = ns.Items.Buttons()[214]
expect(itemButton and itemButton:IsShown() and itemButton:GetAttribute("type") == "item" and itemButton:GetAttribute("item") == "item:5000",
    "a quest's item gets a secure button over its row's slot")
expect(itemButton and itemButton.template == "SecureActionButtonTemplate" and itemButton:GetParent() == UIParent
    and row214.ItemSlot:GetAlpha() == 0, "on UIParent, so the rows stay free to move in combat")
F.combat = true
row214.ItemSlot.top = 760
ns.Items.Sync()
expect(itemButton:GetAlpha() < 0.5 and row214.ItemSlot:GetAlpha() == 1, "in combat, a row that moved dims its button and shows its item grey")
row214.ItemSlot.top = 790
ns.Items.Sync()
expect(itemButton:GetAlpha() == KaLiQuestTracker:GetAlpha() and row214.ItemSlot:GetAlpha() == 0, "lined up again, it's back, at the tracker's opacity")
F.combat = false
row214.ItemSlot.top = 900
ns.Items.Sync()
expect(not itemButton:IsShown() and not ns.Items.Buttons()[214], "a slot scrolled out of view loses its button")
F.RunTimers()
row214.ItemSlot.top = nil
ns.Items.Sync()
row214.ItemSlot.top = 790
F.RunTimers()
expect(ns.Items.Buttons()[214] ~= nil, "a slot with no position yet gets its button at the next frame")
row214.ItemSlot.top = 790
ns.Items.Sync()
itemButton = ns.Items.Buttons()[214]
F.modifier = "CHATLINK"
F.RunScript(itemButton, "PreClick", "LeftButton")
expect(itemButton:GetAttribute("shift-type*") == "item" and F.insertedLink == nil, "a shift-click with no chat box open uses the item")
F.RunScript(itemButton, "PostClick", "LeftButton")
expect(itemButton:GetAttribute("shift-type*") == "", "and only that click")
F.chatOpen = true
F.RunScript(itemButton, "PreClick", "LeftButton")
expect(itemButton:GetAttribute("shift-type*") == "" and F.insertedLink == "item:5000", "with one open, it links the item instead")
F.chatOpen, F.modifier, F.insertedLink = nil, nil, nil
F.ClickSecure(itemButton)
expect(F.usedItemLink == "item:5000", "a click uses the item with the game's default \"act on key down\" too, the button hearing only the release")
F.usedItemLink = nil
do
    local entry214 = F.entries[C_QuestLog.GetLogIndexForQuestID(214)]
    entry214.charges = 3
    ns.RequestRefresh()
    F.RunTimers()
    row214 = rowOf(214)
    row214.ItemSlot.left, row214.ItemSlot.top = 200, 790
    ns.Items.Sync()
    itemButton = ns.Items.Buttons()[214]
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    F.RunTimers()
    entry214.charges = 2
    local realRefresh, redraws = ns.Refresh, 0
    ns.Refresh = function()
        redraws = redraws + 1
        realRefresh()
    end
    for _ = 1, 5 do
        F.RunScript(itemButton, "OnUpdate", 1)
        F.RunTimers()
    end
    ns.Refresh = realRefresh
    expect(itemButton.charges == 2 and redraws == 1 and itemButton.Count:GetText() == 2,
        "a charge used in combat redraws once and shows the new count")
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    entry214.charges = nil
    F.RunTimers()
end
row214.ItemSlot.top = nil
tracker.frames.scroll.top = nil

-- The area highlight, on by default: a quest whose area you're in brightens with an arrow, and its headers count it.
do
    local L = ns.L
    local function check()
        ns.Area.Check()
        F.RunTimers()
    end
    local function signals()
        local out = {}
        for _, a in ipairs((ns.Area.Status())) do
            out[a.title] = a.signal
        end
        return out
    end
    expect(db.options.areaHighlight == true and select(2, ns.Area.Status()), "the area highlight is on and checking, Ikar's default")
    F.blobs = { [214] = true }
    check()
    local row = rowOf(214)
    expect(row and row.area and row.Title:GetText():find("^|A:gearUpdate%-arrow%-bullet%-point:(%d+):%1|a") and (row.AreaFlash.plays or 0) == 1,
        "inside a quest's area, its row brightens, gains the mark, square with the text, and glows once")
    local group = groupOf("Les Mortemines")
    expect(group and group.Here:IsShown() and group.Here:GetText():find("|a1$") and barOf("instances").Here:GetText():find("|a1$")
        and barOf("journal").Here:GetText():find("|a1$") and not barOf("world").Here:IsShown(),
        "its group and every bar above it count it, open as they are, and no other bar")
    check()
    expect(rowOf(214).AreaFlash.plays == 1, "staying there glows nothing more")

    local worldOpen = db.open.categories.world
    db.open.categories.world = nil
    ns.RequestRefresh()
    F.RunTimers()
    local flashes = barOf("world").Flash.plays or 0
    F.distances = { [12] = 200 * 200 }
    check()
    expect((barOf("world").Flash.plays or 0) == flashes + 1 and barOf("world").Here:GetText():find("|a1$"),
        "a quest coming into its area behind a closed bar makes the bar glow and count it")
    F.distances = { [12] = 400 * 400 }
    check()
    expect(not barOf("world").Here:IsShown(), "farther than 300 yards, it isn't here")
    db.open.categories.world = worldOpen

    F.distances = nil
    F.playerPos = { 0.4, 0.6 }
    F.pins = { { questID = 1579, x = 0.5, y = 0.6 }, { questID = 12, x = 0.8, y = 0.6 } }
    check()
    expect(signals()["Rouages"] == L.AREA_PIN and not signals()["La milice du peuple"], "100 yards from a quest's map pin it's here, 400 it isn't")

    F.pins = {}
    local e1579 = F.entries[C_QuestLog.GetLogIndexForQuestID(1579)]
    e1579.objectives = { { text = "Rouage : 0/3", count = 0 } }
    ns.RequestRefresh()
    F.RunTimers()
    e1579.objectives[1].count = 1
    ns.RequestRefresh()
    F.RunTimers()
    local spot = db.spots[1579]
    expect(spot and spot[1] == 1436 and spot[2] == 0.4 and spot[3] == 0.6, "progress learns where the player is")
    F.playerPos = { 0.9, 0.9 }
    check()
    expect(not ns.Area.Is(1579), "away from there, it isn't here")
    F.playerPos = { 0.45, 0.6 }
    check()
    expect(ns.Area.Is(1579) == "spot", "back near it, it is")
    e1579.complete = true
    ns.RequestRefresh()
    F.RunTimers()
    check()
    expect(not ns.Area.Is(1579), "once done, where it progressed no longer counts, as the turn-in is elsewhere")
    e1579.complete = nil
    db.spots[999] = { 1436, 0.1, 0.1 }
    F.Fire("QUEST_REMOVED", 999)
    F.RunTimers()
    expect(db.spots[999] == nil, "a quest leaving the log forgets its spot")

    local panel = table.concat(ns.DebugPanel.Lines(), "\n")
    expect(panel:find(L.DIAG_AREA, 1, true) and panel:find("Les masques rouges en soie : " .. L.AREA_BLOB, 1, true),
        "the diagnostic panel lists the quests here with their signal")

    click(gear)
    F.MenuItem(L.AREA_HIGHLIGHT).choose()
    F.RunTimers()
    expect(db.options.areaHighlight == false and not rowOf(214).area and not select(2, ns.Area.Status())
        and not groupOf("Les Mortemines").Here:IsShown(), "the gear's switch turns it off: no arrow, no counts, no check")
    db.spots[1579] = nil
    e1579.objectives[1].count = 2
    ns.RequestRefresh()
    F.RunTimers()
    expect(db.spots[1579] == nil, "off, progress learns nothing")
    local plays = rowOf(214).AreaFlash.plays or 0
    setLook("areaHighlight", true)
    F.RunTimers()
    expect(rowOf(214).area and (rowOf(214).AreaFlash.plays or 0) == plays,
        "switched on from Edit Mode's dialog, a quest already here shows without a glow")
    F.blobs, F.playerPos, F.pins, e1579.objectives = nil, nil, nil, nil
    check()
end

-- Blizzard's map button and find-group eye. Forever doesn't load Blizzard's group finder, so there the eye and its
-- option don't show.
db.open.categories.world, db.open.headers["Marche de l'Ouest"] = true, true
expect(db.options.findGroup == false, "the find-group eye is off by default, Ikar's defaults")
expect(F.settingsCategory.settings.KALIQUEST_FINDGROUP == nil, "without the group finder, as on Forever, the options page doesn't offer the eye")
db.options.findGroup = true
F.findGroup = { [12] = true }
ns.RequestRefresh()
F.RunTimers()
expect(not (rowOf(12).Eye and rowOf(12).Eye:IsShown()), "nor do rows show it, as it would open nothing")
LFGListUtil_FindQuestGroup = function() end
ns.RequestRefresh()
F.RunTimers()
expect(rowOf(12).Eye and rowOf(12).Eye:IsShown() and rowOf(12).Eye.setUpQuestID == 12,
    "where the group finder loads, a quest that can find a group shows Blizzard's eye")
expect(F.questUtilFindGroupCalls == nil, "asked of C_LFGList, never QuestUtil, whose cache our calls would taint")
db.options.findGroup = false
ns.RequestRefresh()
F.RunTimers()
expect(not rowOf(12).Eye:IsShown(), "the option hides it")
LFGListUtil_FindQuestGroup = nil
F.findGroup = nil
F.cvars.questPOI = "1"
F.Fire("CVAR_UPDATE", "questPOI")
F.RunTimers()
expect(rowOf(12).POI and rowOf(12).POI:IsShown() and rowOf(12).POI:GetQuestID() == 12, "with the map's quest objectives on, rows have their map button")
F.cvars.questPOI = nil
F.Fire("CVAR_UPDATE", "questPOI")
F.RunTimers()
expect(not rowOf(12).POI:IsShown(), "and none with them off")

-- Markers: an icon only where the row's place doesn't say it, the off-list pin first, and no tooltip.
do
    db.open.categories.journal, db.open.categories.classprof, db.open.headers.Forgeron = true, true, true
    db.open.categories.instances, db.open.headers["Les Mortemines"] = true, true
    F.tags = { [1579] = { tagID = 81 }, [214] = { tagID = 81 } }
    ns.RequestRefresh()
    F.RunTimers()
    local dungeon = "|A:questlog-questtypeicon-dungeon:13:13|a"
    expect(rowOf(1579).Title:GetText():find(dungeon, 1, true) and not rowOf(214).Title:GetText():find("|A:", 1, true),
        "a dungeon quest outside Donjons et raids shows the dungeon icon, one inside doesn't")
    -- Forever Quest Tint marks the titles it finds by their bare text, and hooks each one's SetText to mark it again.
    -- A row's hidden copy of its title is what it finds; the row shows the mark, then its own markers.
    do
        local copy, fqt = rowOf(1579).TitleSource, true
        local bare = copy:GetText()
        hooksecurefunc(copy, "SetText", function(self, text)
            if fqt and text == bare then
                self:SetText(bare .. " ∞")
            end
        end)
        copy:SetText(bare)
        F.RunTimers()
        local marked = rowOf(1579).Title:GetText()
        local mark, icon = marked:find(bare .. " ∞", 1, true), marked:find(dungeon, 1, true)
        expect(mark and icon and mark < icon, "a mark another addon puts on the row's hidden title copy shows, before the row's markers: " .. marked)
        fqt = false
        ns.RequestRefresh()
        F.RunTimers()
    end
    F.tooltip = { lines = {} }
    F.RunScript(rowOf(1579), "OnEnter")
    local tipShown = F.tooltip.shown or #F.tooltip.lines > 0
    F.RunScript(rowOf(1579), "OnLeave")
    expect(not tipShown, "and no tooltip names it, icons only, Ikar's ruling on 2026-11-10")
    setLook("markerSize", 16)
    F.RunTimers()
    expect(rowOf(1579).Title:GetText():find(":16:16|a", 1, true), "the marker size option sizes it")
    setLook("markerSize", 13)
    local g = db.groups[1]
    ns.model:MoveQuest(214, g.id)
    db.open.categories.mine, db.open.groups[g.id] = true, true
    F.watched[214] = nil
    ns.RequestRefresh()
    F.RunTimers()
    local text = rowOf(214).Title:GetText()
    local pin = text:find("waypoint-mappin-minimap-untracked", 1, true)
    expect(pin and text:find(dungeon, 1, true) and pin < text:find(dungeon, 1, true),
        "in a player's group, past the game's 25, the off-list pin comes first, and the dungeon icon shows there too")
    ns.model:MoveQuest(214, nil)
    F.tags = { [1579] = { tagID = 88 } }
    ns.RequestRefresh()
    F.RunTimers()
    expect(rowOf(1579).Title:GetText():find("|A:questlog-questtypeicon-raid:", 1, true)
        and ns.Filter.Traits({ id = 1579 }, {}).type.raid, "a 10-player raid quest shows the raid icon and counts as a raid")

    -- The plan's other markers, in its order, three at most.
    local e1579 = F.entries[C_QuestLog.GetLogIndexForQuestID(1579)]
    F.timed = { [1579] = { 600, 30 } }
    F.tags = { [1579] = { tagID = 83 } }
    e1579.suggestedGroup, e1579.frequency = 5, 1
    ns.RequestRefresh()
    F.RunTimers()
    local t = rowOf(1579).Title:GetText()
    local clock, size, daily = t:find("questtypeicon-clockyellow", 1, true), t:find("questtypeicon-group:13:13|a5", 1, true),
        t:find("questtypeicon-daily", 1, true)
    expect(clock and size and daily and clock < size and size < daily and not t:find("legendary", 1, true),
        "timed, then group of 5 with its number, then daily: three at most, in the plan's order")
    F.timed, F.tags = nil, nil
    e1579.suggestedGroup, e1579.frequency = 0, 2
    ns.RequestRefresh()
    F.RunTimers()
    expect(rowOf(1579).Title:GetText():find("questtypeicon-weekly", 1, true), "a weekly quest shows the weekly icon")
    e1579.frequency = 0
    F.repeatable[1579] = true
    ns.RequestRefresh()
    F.RunTimers()
    expect(rowOf(1579).Title:GetText():find("|A:questrepeatableturnin:", 1, true), "a repeatable one, the repeatable icon")
    F.repeatable[1579] = nil
    local header
    for _, e in ipairs(F.entries) do
        if e.isHeader and e.title == "Forgeron" then
            header = e
        end
    end
    header.title = "Guerrier"
    db.open.headers.Guerrier = true
    ns.RequestRefresh()
    F.RunTimers()
    expect(rowOf(1579) and not rowOf(1579).Title:GetText():find("questtypeicon-class", 1, true), "under its class header, no class icon")
    db.open.headers.Guerrier = nil
    ns.model:MoveQuest(1579, g.id)
    ns.RequestRefresh()
    F.RunTimers()
    expect(rowOf(1579).Title:GetText():find("questtypeicon-class", 1, true), "a quest from the class header moved into Suivi shows the class icon")
    ns.model:MoveQuest(1579, nil)
    header.title = "Forgeron"
    F.tags = nil
    ns.RequestRefresh()
    F.RunTimers()
    expect(rowOf(1579) and not rowOf(1579).Title:GetText():find("|A:", 1, true), "a plain quest in its own place has none")

    -- The option: icons, text or none.
    local choices = {}
    for _, c in ipairs(lookRow("markerStyle").values) do
        choices[#choices + 1] = c[1] .. "=" .. c[2]
    end
    expect(db.options.markerStyle == "icons" and table.concat(choices, ",") == "icons=Icônes,text=Texte,none=Aucun",
        "icons by default, and Edit Mode's dialog offers Icônes, Texte and Aucun: " .. table.concat(choices, ","))
    F.tags = { [1579] = { tagID = 81 } }
    e1579.suggestedGroup = 5
    setLook("markerStyle", "text")
    F.RunTimers()
    t = rowOf(1579).Title:GetText()
    expect(t:find("(5)", 1, true) and t:find("(Donjon)", 1, true) and not t:find("|A:", 1, true), "as text, they read (5) and (Donjon): " .. t)
    setLook("markerStyle", "none")
    F.RunTimers()
    t = rowOf(1579).Title:GetText()
    expect(not t:find("(5)", 1, true) and not t:find("|A:", 1, true), "none: the title has none")
    setLook("markerStyle", "text")
    setLook("dungeon", false, true)
    F.RunTimers()
    t = rowOf(1579).Title:GetText()
    expect(db.options.markers.dungeon == false and t:find("(5)", 1, true) and not t:find("Donjon", 1, true),
        "a marker switched off in Edit Mode's dialog doesn't show; the others stay")
    setLook("dungeon", true, true)
    setLook("markerStyle", "icons")
    F.tags, e1579.suggestedGroup = nil, 0
    F.RunTimers()
end

-- The share button: only in a party where someone lacks the quest, and by default only under the pointer.
do
    F.inGroup, F.partySize, F.partyOn = true, 2, { [12] = 1 }
    ns.RequestRefresh()
    F.RunTimers()
    local r = rowOf(12)
    expect(r.canShare and not r.Share:IsShown(), "in a party where someone lacks the quest, the share button waits for the pointer")
    F.tooltip = { lines = {} }
    F.RunScript(r, "OnEnter")
    expect(r.Share:IsShown(), "and shows on hover")
    local said = F.triggered[#F.triggered]
    expect(not F.tooltip.shown and #F.tooltip.lines == 0 and said.event == "OnQuestBlockHeader.OnEnter" and said.args[3] == false,
        "in a party, hovering a quest shows no party progress, Ikar's ruling on 2026-11-10, and tells other addons no tooltip is up")
    click(r.Share)
    expect(F.shared == 12, "it shares the quest")
    F.RunScript(r, "OnLeave")
    expect(not r.Share:IsShown(), "and hides once the pointer leaves")
    r.mouseOver = true
    F.RunScript(r, "OnEnter")
    F.RunScript(r, "OnLeave")
    expect(r.Share:IsShown(), "moving onto the row's eye or item keeps it")
    r.mouseOver = nil
    F.RunScript(r.Share, "OnUpdate", 0.02)
    expect(not r.Share:IsShown(), "and leaving from there hides it, though the row never hears")
    F.shared = nil
    click(r, "RightButton")
    F.MenuItem("Partage de quête").choose()
    expect(F.shared == 12, "the quest's menu shares it too")
    setLook("shareOnHover", false)
    F.RunTimers()
    expect(rowOf(12).Share:IsShown(), "with the option off it always shows")
    F.partyOn[12] = 2
    ns.RequestRefresh()
    F.RunTimers()
    expect(not rowOf(12).Share:IsShown(), "and not once everyone has the quest")
    setLook("shareOnHover", true)
    F.inGroup, F.partySize, F.partyOn = nil, nil, nil
    F.RunTimers()
end

-- Tracked recipes and achievements, as bars of their own below Journal.
do
    F.recipes[false] = { 2000 }
    F.schematics[2000] = { name = "Potion de soins", reagentSlotSchematics = {
        { required = true, reagentType = 1, reagents = { { itemID = 765 } }, quantityRequired = 2, variableQuantities = {} },
        { required = true, reagentType = 0, reagents = { { itemID = 1 } }, quantityRequired = 1, variableQuantities = {}, slotInfo = { slotText = "Fiole" } },
        { required = false, reagentType = 1, reagents = { { itemID = 2 } }, quantityRequired = 1, variableQuantities = {} },
    } }
    F.itemCounts[765] = 3
    F.achievements = { 500 }
    F.achievementInfo[500] = { name = "Explorateur", description = "Explorer le monde", criteria = {
        { text = "A", done = true }, { text = "B" }, { text = "C", eligible = false }, { text = "D" }, { text = "E" }, { text = "F" },
        { text = "G" }, { text = "H" } } }
    F.Fire("TRACKED_RECIPE_UPDATE", 2000, true)
    F.Fire("CONTENT_TRACKING_UPDATE", 2, 500, true)
    F.RunTimers()
    local function entryOf(key)
        return shown("entry", function(line)
            return line.entry.key == key
        end)
    end
    local function lineTexts(row)
        local t = {}
        for i = 1, row and row.shownLines or 0 do
            t[i] = row.lines[i].Text:GetText()
        end
        return row and table.concat(t, "|") or "(no row)"
    end
    local tops = {}
    for _, l in ipairs(tracker.lines) do
        if l.kind == "bar" and l.top then
            tops[#tops + 1] = l.id
        end
    end
    expect(table.concat(tops, ",") == "mine,journal,achievements" and (F.itemLoads[765] or 0) >= 1,
        "a recipe waits until its items' names load, asking for them: " .. table.concat(tops, ","))
    F.Fire("ITEM_DATA_LOAD_RESULT", 999, true)
    F.Fire("CRITERIA_UPDATE")
    expect(#F.timers == 0, "another item loading, or progress on an untracked achievement, doesn't redraw")
    F.itemNames[765] = "Feuillargent"
    F.Fire("ITEM_DATA_LOAD_RESULT", 765, true)
    expect(#F.timers > 0, "the awaited item does")
    F.RunTimers()
    tops = {}
    for _, l in ipairs(tracker.lines) do
        if l.kind == "bar" and l.top then
            tops[#tops + 1] = l.id
        end
    end
    expect(table.concat(tops, ",") == "mine,journal,recipes,achievements",
        "recipes and achievements get bars of their own below Journal: " .. table.concat(tops, ","))
    -- Another addon's frame on Blizzard's parked recipe header, as Auctionator's search button, shows on the bar.
    ProfessionsRecipeTracker = CreateFrame("Frame", "ProfessionsRecipeTracker", nil)
    local recipeHeader = CreateFrame("Frame", nil, ProfessionsRecipeTracker)
    ProfessionsRecipeTracker.Header = recipeHeader
    recipeHeader.MinimizeButton = CreateFrame("Button", nil, recipeHeader)
    local foreign = CreateFrame("Frame", nil, recipeHeader)
    foreign:SetSize(100, 22)
    foreign:SetPoint("TOPRIGHT", recipeHeader, "TOPRIGHT", -40, 0)
    ns.RequestRefresh()
    F.RunTimers()
    expect(foreign:GetParent() == barOf("recipes") and recipeHeader.MinimizeButton:GetParent() == recipeHeader,
        "another addon's frame on Blizzard's recipe header shows on the recipes bar; the header's own button stays")
    local recipe, achievement = entryOf("r2000"), entryOf("a500")
    expect(recipe and recipe.Title:GetText() == "Potion de soins" and lineTexts(recipe) == "0 / 1 Fiole|3 / 2 Feuillargent"
        and recipe.lines[2].Check:IsShown() and not recipe.lines[1].Check:IsShown(),
        "then lists its required reagents, modifying ones first, checked once there are enough: " .. lineTexts(recipe))
    F.Fire("BAG_UPDATE_DELAYED")
    expect(#F.timers > 0, "with a recipe tracked, bags redraw")
    F.RunTimers()
    expect(achievement and lineTexts(achievement) == "B|C|D|E|F|...", "an achievement shows five unfinished criteria, then ...: " .. lineTexts(achievement))
    expect(achievement and achievement.lines[2].style == "failed", "one that can't be had any more in the failed colour")
    local function fadeIns()
        local n = 0
        for _, f in ipairs(tracker.pools.entry.frames) do
            n = n + (f.FadeIn.plays or 0)
        end
        return n
    end
    local fades = fadeIns()
    click(barOf("recipes"))
    expect(db.open.categories.recipes == false and not entryOf("r2000"), "its bar closes it: " .. tostring(db.open.categories.recipes))
    click(barOf("recipes"))
    local again = entryOf("r2000")
    expect(again and fadeIns() == fades, "and opens it again, without fading it in as new")
    if again then
        click(again)
    end
    expect(F.openedRecipe == 2000, "clicking a recipe opens it")
    F.modifier = "QUESTWATCHTOGGLE"
    click(entryOf("a500"))
    F.modifier = nil
    expect(#F.achievements == 0 and not entryOf("a500"), "a modified click stops tracking an achievement")
    click(entryOf("r2000"), "RightButton")
    F.MenuItem("Arrêter le suivi").choose()
    F.RunTimers()
    expect(#F.recipes[false] == 0 and not barOf("recipes"), "the menu stops tracking a recipe, and an empty section goes")
    expect(foreign:GetParent() == recipeHeader and select(2, foreign:GetPoint()) == recipeHeader and select(4, foreign:GetPoint()) == -40,
        "and the other addon's frame goes back to the header, where it was")
    ProfessionsRecipeTracker = nil
    F.Fire("BAG_UPDATE_DELAYED")
    F.Fire("CURRENCY_DISPLAY_UPDATE")
    expect(#F.timers == 0, "with none tracked, bags and currencies don't redraw")
end

-- Blizzard's "Temps" panel of timed quests, as the popups: scaled with the text up to the rows' width, centred on them,
-- and zoomed with them.
do
    local o = db.options
    local width = o.width
    local function placed(on)
        local point, rel, relPoint, x, y = QuestTimerFrame:GetPoint()
        local s = QuestTimerFrame:GetScale()
        return point == "TOP" and rel == (on or KaLiQuestHolder) and relPoint == "TOP", s, (x or 0) * s, (y or 0) * s
    end
    F.questTimerHeight = 59
    o.width = 310
    ObjectiveTrackerManager:SetTextSize(18)
    ns.RequestRefresh()
    F.RunTimers()
    local ok, scale, x, y = placed()
    local _, _, _, _, titleY = tracker.frames.title:GetPoint()
    expect(ok and math.abs(scale - 1) < 0.001 and math.abs(x + 6) < 0.01 and math.abs(y + 10) < 0.01,
        "Edit Mode's text size no longer sizes the panel: the rows' own size, 10 under the frame's top, centred on the rows: "
        .. scale .. " " .. x .. " " .. y)
    expect(math.abs(-titleY - (59 + 18)) < 0.01, "and the rows start under it, as Blizzard's sections would: " .. -titleY)
    ObjectiveTrackerManager:SetTextSize(12)
    o.zoom = 150
    ns.RequestRefresh()
    F.RunTimers()
    ok, scale, x, y = placed()
    _, _, _, _, titleY = tracker.frames.title:GetPoint()
    expect(ok and math.abs(scale - 1.5) < 0.001 and math.abs(x + 9) < 0.01 and math.abs(y + 15) < 0.01,
        "zoomed by half, it grows with the rows, 10 of their units under the frame's top, centred on them: " .. scale .. " " .. x .. " " .. y)
    expect(math.abs(-titleY - (59 + 18)) < 0.01, "and the zoomed rows start under it: " .. -titleY)
    o.zoom = 100
    o.width = 220
    ns.RequestRefresh()
    F.RunTimers()
    ok, scale = placed()
    expect(math.abs(scale - 1) < 0.001, "it never grows wider than the rows: " .. scale)
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    ok, scale, x, y = placed(ObjectiveTrackerFrame)
    expect(ok and scale == 1 and math.abs(x) < 0.01 and math.abs(y + 10) < 0.01, "with Blizzard's tracker back, it's Blizzard's size and place again")
    SlashCmdList.KALIQUEST("tracker on")
    ObjectiveTrackerManager:SetTextSize(12)
    o.width, F.questTimerHeight = width, nil
    ns.RequestRefresh()
    F.RunTimers()
end

-- Achievements as Blizzard's: timer bars, sliding in when tracked, the turn-in when earned.
do
    local function entryOf(key)
        return shown("entry", function(line)
            return line.entry.key == key
        end)
    end
    F.achievementInfo[501] = { name = "Contre la montre", description = "Vite", criteria = {
        { text = "Course", duration = 60, elapsed = 15 }, { text = "Fini", done = true }, { text = "Ensuite" } } }
    F.achievementInfo[502] = { name = "Sans critère", description = "Tenir 30 secondes", criteria = {} }
    F.achievements = { 501, 502 }
    F.Fire("CONTENT_TRACKING_UPDATE", 2, 501, true)
    F.RunTimers()
    local a501 = entryOf("a501")
    expect(a501 and (a501.HeadSweep.plays or 0) >= 1 and (a501.FadeIn.plays or 0) >= 1,
        "a newly tracked achievement slides in, the glow sweeping its title, as Blizzard's")
    local bar = a501 and a501.timers and a501.timers[1]
    expect(bar and bar:IsShown() and bar.duration == 60 and (bar.Label:GetText() or ""):find("^0:4"),
        "a criterion with a running timer gets Blizzard's timer bar, with the time left: " .. tostring(bar and bar.Label:GetText()))
    local a502 = entryOf("a502")
    expect(a502 and not (a502.timers and a502.timers[1] and a502.timers[1]:IsShown()),
        "one without criteria has no bar until the game reports its timer")
    F.Fire("TRACKED_ACHIEVEMENT_UPDATE", 502, 9001, 10, 30)
    F.RunTimers()
    a502 = entryOf("a502")
    local t502 = a502 and a502.timers and a502.timers[1]
    expect(t502 and t502:IsShown() and t502.duration == 30, "the game's report gives it one")
    F.Advance(25)
    F.RunScript(t502, "OnUpdate", 0.1)
    F.RunTimers()
    a502 = entryOf("a502")
    expect(a502 and a502.lines[1].style == "failed" and not a502.timers[1]:IsShown(),
        "run out, the bar goes and the achievement takes the failed colour")

    F.achievementInfo[501].earned = true
    F.Fire("ACHIEVEMENT_EARNED", 501)
    ns.Refresh()
    local leaving = entryOf("a501")
    expect(leaving and leaving.line.entry.leaving and (leaving.FadeOut.plays or 0) >= 1,
        "earned, it keeps its place while Blizzard's turn-in plays")
    F.RunTimers()
    expect(not entryOf("a501") and entryOf("a502"), "then it goes")
    click(barOf("achievements"))
    F.achievementInfo[502].earned = true
    F.Fire("ACHIEVEMENT_EARNED", 502)
    F.RunTimers()
    expect(not barOf("achievements"), "one earned behind its closed bar goes at once")
    F.achievements = {}
    db.open.categories.achievements = nil
    F.RunTimers()
end

-- An error while drawing gives Blizzard's tracker back, says so once, and /kq tracker on tries again.
do
    local read = ns.Sections.Read
    ns.Sections.Read = function()
        error("smoke: a failing layout")
    end
    local printed = #F.printed
    ns.RequestRefresh()
    F.RunTimers()
    ns.Sections.Read = read
    expect(not tracker.IsActive() and not ns.Host.IsParked() and not KaLiQuestTracker:IsShown()
        and (F.printed[printed + 1] or ""):find("/kq tracker on", 1, true),
        "an error while drawing gives Blizzard's tracker back and says how to retry")
    expect(db.options.tracker == true, "without changing the saved choice")
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    expect(tracker.IsActive() and ns.Host.IsParked() and KaLiQuestTracker:IsShown(), "and /kq tracker on brings it back")
    for msg in pairs(KaLiQuestDevDB.errors) do
        if msg:find("smoke: a failing layout", 1, true) then
            KaLiQuestDevDB.errors[msg] = nil
        end
    end
    for i = #F.errors, 1, -1 do
        if F.errors[i]:find("smoke: a failing layout", 1, true) then
            table.remove(F.errors, i)
        end
    end
end

-- Blizzard's sections the addon doesn't draw: one that fills makes the addon step aside until it empties.
do
    local warnings = #F.uiWarnings
    F.filled.ScenarioObjectiveTracker = true
    F.UpdateSections()
    F.RunTimers()
    expect(not tracker.IsActive() and not ns.Host.IsParked() and (F.uiWarnings[warnings + 1] or ""):find("Scénario", 1, true),
        "a scenario showing in Blizzard's hidden section gives Blizzard's tracker back, with an alert on top")
    local seen = KaLiQuestDevDB.sectionsSeen and KaLiQuestDevDB.sectionsSeen.ScenarioObjectiveTracker
    expect(seen and seen.count == 1, "and is remembered, to learn what fills on Forever")
    F.filled.ScenarioObjectiveTracker = nil
    F.UpdateSections()
    F.RunTimers()
    expect(tracker.IsActive() and ns.Host.IsParked(), "once it's empty, KaLi Quest's tracker comes back")
    F.combat = true
    F.filled.BonusObjectiveTracker = true
    F.UpdateSections()
    F.RunTimers()
    expect(tracker.IsActive(), "in a fight, the switch waits")
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    F.RunTimers()
    expect(not tracker.IsActive(), "for the fight's end")
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    local line = ns.Coverage.Line()
    expect(tracker.IsActive() and line:IsShown() and (line.Text:GetText() or ""):find("Objectifs bonus", 1, true),
        "/kq tracker on keeps KaLi Quest's, with an alert on top naming what only Blizzard's shows")
    click(line)
    expect(not tracker.IsActive(), "clicking the alert switches to Blizzard's")
    F.filled.BonusObjectiveTracker = nil
    F.UpdateSections()
    F.RunTimers()
    expect(tracker.IsActive() and not ns.Coverage.Line():IsShown(), "and KaLi Quest's comes back once it's over")
    C_QuestLog.GetNumWorldQuestWatches = function()
        return 1
    end
    F.UpdateSections()
    F.RunTimers()
    expect(not tracker.IsActive(), "a tracked world quest counts even when its section had no room to look")
    C_QuestLog.GetNumWorldQuestWatches = nil
    F.UpdateSections()
    F.RunTimers()
    expect(tracker.IsActive(), "and KaLi Quest's comes back")
    local other = CreateFrame("Frame", "AutreAddonTracker", nil)
    other.headerText, other.hasContents = "Autre addon", true
    table.insert(ObjectiveTrackerFrame.modules, other)
    F.UpdateSections()
    F.RunTimers()
    expect(not tracker.IsActive() and (F.uiWarnings[#F.uiWarnings] or ""):find("Autre addon", 1, true),
        "another addon's own section in Blizzard's tracker counts too")
    table.remove(ObjectiveTrackerFrame.modules)
    F.UpdateSections()
    F.RunTimers()
    expect(tracker.IsActive(), "until it's gone")
    local warned = #F.uiWarnings
    SlashCmdList.KALIQUEST("alert")
    F.RunTimers()
    expect(not tracker.IsActive() and #F.uiWarnings == warned + 1 and seen.count == 1
        and ns.Coverage.Changes()[1]:find("simulé par le test", 1, true),
        "/kq alert simulates a scenario to try it in game, without counting it as seen, and its log line says it's a test")
    SlashCmdList.KALIQUEST("alert")
    F.RunTimers()
    expect(tracker.IsActive() and ns.Coverage.Changes()[1]:find("fin du test", 1, true), "and again ends the test")
end

-- The debug panel: live state, every section, and a report to copy.
do
    SlashCmdList.KALIQUEST("diag")
    local panel, buttons = ns.DebugPanel.Frames()
    expect(panel and panel:IsShown(), "/kq diag opens the debug panel")
    F.RunScript(panel, "OnUpdate", 1)
    local body = panel and panel.Body:GetText() or ""
    expect(body:find("Suivi : affiché", 1, true) and body:find("Scénario : vide · vue 1 fois", 1, true)
        and body:find("Quêtes : dessinée par KaLi Quest", 1, true), "it shows the tracker's state and every section: " .. body)
    expect(body:find("Les masques rouges en soie : ", 1, true), "and each quest item with what became of its button")
    F.recipes[false], F.achievements = { 2000, 2001 }, { 500 }
    F.RunScript(panel, "OnUpdate", 1)
    expect((panel.Body:GetText() or ""):find("Métier : 2 · hauts faits : 1", 1, true), "and how many recipes and achievements are tracked")
    F.recipes[false], F.achievements = {}, {}
    click(buttons.debug)
    ns.Debug.Log("smoke", "une ligne")
    F.RunScript(panel, "OnUpdate", 1)
    expect(KaLiQuestDevDB.debug and (panel.Body:GetText() or ""):find("une ligne", 1, true), "with debug mode on, the log's last lines show in it")
    click(buttons.debug)
    click(buttons.copy)
    local reportFrame = ns.Report.Frame()
    local report = reportFrame and reportFrame:IsShown() and reportFrame.Box:GetText() or ""
    expect(report:find("== errors ==", 1, true) and report:find("Scénario", 1, true) and not report:find("|c", 1, true),
        "its copy button opens the bug report, plain text with the errors and every section")
    if reportFrame then
        reportFrame:Hide()
    end
    click(buttons.tracker)
    expect(not tracker.IsActive(), "its switch gives Blizzard's tracker")
    click(buttons.tracker)
    expect(tracker.IsActive(), "and takes it back")
    SlashCmdList.KALIQUEST("diag")
    expect(not panel:IsShown(), "/kq diag closes it again")
end

-- The sliders, in Edit Mode's dialog: one for each saved number, in the range loading keeps it in.
do
    local wrong, seen = {}, {}
    for _, section in ipairs(ns.EditPanel.handle:Sections()) do
        for _, row in ipairs(section.rows) do
            if row.kind == "slider" then
                seen[row.key] = true
                if ns.EditPanel.handle:Range(row) ~= ns.DB.RANGES[row.key] then
                    wrong[#wrong + 1] = row.key
                end
            end
        end
    end
    for key in pairs(ns.DB.RANGES) do
        if not seen[key] then
            wrong[#wrong + 1] = key
        end
    end
    expect(#wrong == 0, "every saved number has its slider in Edit Mode's dialog, in the range loading keeps it in: "
        .. table.concat(wrong, ", "))
end
setLook("width", 300)
F.RunTimers()
expect(KaLiQuestTracker:GetWidth() == 300 and ObjectiveTrackerFrame:GetWidth() == 300 + ns.Host.SCROLLBAR_ROOM,
    "the width option widens the rows and the host")
setLook("width", 260)
setLook("height", 400)
F.RunTimers()
expect(KaLiQuestTracker:GetHeight() == 400, "the height option sets the tracker's height")
db.options.height = nil
setLook("opacity", 50)
F.RunTimers()
expect(KaLiQuestTracker:GetAlpha() == 0.5, "the opacity option fades it")
setLook("opacity", 100)
-- The zoom scales the whole tracker, Ikar's ruling on 2026-11-10: the rows and Edit Mode's box, not the height on
-- screen nor the text's size, which stays Edit Mode's.
expect(lookRow("textSize") == nil and ns.EditPanel.handle:Value(lookRow("zoom")) == 100,
    "a zoom at 100 %, and no text size of the addon's own")
local heightBefore = KaLiQuestTracker:GetHeight()
setLook("zoom", 150)
F.RunTimers()
expect(KaLiQuestTracker:GetScale() == 1.5 and ObjectiveTrackerFrame:GetWidth() == (260 + ns.Host.SCROLLBAR_ROOM) * 1.5,
    "zoomed by half, the rows grow and Edit Mode's box with them")
expect(math.abs(KaLiQuestTracker:GetHeight() * 1.5 - heightBefore) < 0.01 and select(2, KaLiQuestLineFont:GetFont()) == 12,
    "the tracker keeps its height on screen, and the text Edit Mode's size")
do
    local row = rowOf(12)
    local groupsHeld = db.groups
    db.groups = {}
    F.RunScript(row, "OnEnter")
    local tipX = select(4, GameTooltip:GetPoint())
    F.RunScript(row, "OnLeave")
    db.groups = groupsHeld
    F.RunScript(row, "OnEnter")
    F.modifier = "QUESTWATCHTOGGLE"
    F.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    local hintX = select(4, ns.Tracker.Shared.hint:GetPoint())
    F.modifier = nil
    F.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    F.RunScript(row, "OnLeave")
    expect(math.abs(tipX + row.gutter * 1.5) < 0.01 and math.abs(hintX + row.gutter * 1.5 / 0.75) < 0.01,
        "the tooltip and the click word stay clear of the zoomed level badge: " .. tostring(tipX) .. " " .. tostring(hintX))
end
setLook("zoom", 100)
F.RunTimers()
expect(KaLiQuestTracker:GetScale() == 1 and ObjectiveTrackerFrame:GetWidth() == 260 + ns.Host.SCROLLBAR_ROOM, "and back to 100 %")
ObjectiveTrackerManager:SetTextSize(16)
F.RunTimers()
expect(select(2, KaLiQuestLineFont:GetFont()) == 12 and select(2, KaLiQuestHeaderFont:GetFont()) == 14
    and KaLiQuestLineFont.parentFont == ObjectiveTrackerFont12 and KaLiQuestHeaderFont.parentFont == ObjectiveTrackerFont14,
    "the rows' fonts are Blizzard's tracker fonts at 12 and 14, whatever Edit Mode's text size: the zoom alone sizes them")
local fontSets = KaLiQuestLineFont.sets
ns.RequestRefresh()
F.RunTimers()
expect(KaLiQuestLineFont.sets == fontSets, "a redraw that changes no size leaves the fonts alone")
ObjectiveTrackerManager:SetTextSize(12)
F.RunTimers()

-- Motion: what's new glows, a quest accepted in combat waits, a removed one fades where it was.
local function plays(poolName, key)
    local n = 0
    for _, f in ipairs(tracker.pools[poolName].frames) do
        n = n + (f[key] and f[key].plays or 0)
    end
    return n
end
db.open.headers["Marche de l'Ouest"] = nil
ns.RequestRefresh()
F.RunTimers()
local flashes0 = plays("group", "Flash")
table.insert(F.entries, 2, quest(600, "Nouvelle"))
F.Fire("QUEST_ACCEPTED", 600)
F.RunTimers()
expect(plays("group", "Flash") == flashes0 + 1, "a quest accepted behind a closed header makes it glow")
db.open.headers["Marche de l'Ouest"] = true
ns.RequestRefresh()
F.RunTimers()
local sweeps0 = plays("row", "HeadSweep")
table.insert(F.entries, 2, quest(601, "Visible"))
F.Fire("QUEST_ACCEPTED", 601)
F.RunTimers()
expect(rowOf(601) and plays("row", "HeadSweep") == sweeps0 + 1, "one whose row shows glows in")
local glows0 = plays("row", "ProgressGlow")
entry12 = F.entries[C_QuestLog.GetLogIndexForQuestID(12)]
entry12.objectives[1].count = 3
ns.RequestRefresh()
F.RunTimers()
expect(plays("row", "ProgressGlow") == glows0 + 1, "progress glows the row once")
db.options.progressFlash = false
entry12.objectives[1].count = 4
ns.RequestRefresh()
F.RunTimers()
expect(plays("row", "ProgressGlow") == glows0 + 1, "unless the option is off")
db.options.progressFlash = true
F.combat = true
F.Fire("PLAYER_REGEN_DISABLED")
table.insert(F.entries, 2, quest(602, "Pendant le combat"))
F.Fire("QUEST_ACCEPTED", 602)
F.RunTimers()
expect(not rowOf(602), "a quest accepted in combat waits")
local sweepsHeld = plays("row", "HeadSweep")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()
expect(rowOf(602) and plays("row", "HeadSweep") == sweepsHeld + 1, "and shows once the fight ends, glowing in then")
expect(rowOf(602).HeadGlow:GetWidth() == rowOf(602):GetWidth(), "the glow spans the row")
local fades0, sweeps602 = plays("row", "FadeOut"), plays("row", "HeadSweep")
removeFromLog(602)
F.Fire("QUEST_REMOVED", 602)
F.Fire("QUEST_LOG_UPDATE")
F.RunTimers()
expect(plays("row", "FadeOut") == fades0 + 1 and plays("row", "HeadSweep") == sweeps602 and not rowOf(602),
    "a removed quest's row fades where it was, then goes")
local fades601, sweeps601 = plays("row", "FadeOut"), plays("row", "HeadSweep")
removeFromLog(601)
F.Fire("QUEST_TURNED_IN", 601, 0, 0)
F.Fire("QUEST_REMOVED", 601)
F.Fire("QUEST_LOG_UPDATE")
F.RunTimers()
expect(plays("row", "FadeOut") == fades601 + 1 and plays("row", "HeadSweep") == sweeps601 + 1 and not rowOf(601),
    "a turned-in one's title gets Blizzard's sweep before it fades")
for _, id in ipairs({ 600 }) do
    removeFromLog(id)
    F.Fire("QUEST_REMOVED", id)
end
F.RunTimers()

-- Drag and drop, with the pointer given in the list's own height.
local content = tracker.frames.content
content.top, content.left = 1000, 0
local function yOf(f)
    return -select(5, f:GetPoint())
end
local function dragTo(frame, y)
    F.RunScript(frame, "OnDragStart", "LeftButton")
    F.cursorX, F.cursorY = 50, 1000 - y
    F.RunScript(frame, "OnDragStop")
    F.RunTimers()
end
local function indexIn(g, id)
    for i, q in ipairs(g.quests) do
        if q == id then
            return i
        end
    end
end
local gA, gB = db.groups[1], db.groups[2]
db.open.categories.mine, db.open.groups[gA.id], db.open.groups[gB.id] = true, true, true
db.open.categories.world, db.open.headers["Marche de l'Ouest"] = true, true
db.open.categories.classprof, db.open.headers.Forgeron = true, true
ns.RequestRefresh()
F.RunTimers()
expect(ns.model:GroupOf(300) == gA and not ns.model:GroupOf(12), "drag setup: 300 in the first group, 12 in the log")
F.RunScript(rowOf(12), "OnDragStart", "LeftButton")
expect(ns.Drag.Active() and rowOf(12):GetAlpha() == 0.4, "dragging dims the row")
F.cursorX, F.cursorY = 50, 1000 - (yOf(groupOf(gB.name)) + 2)
F.RunScript(rowOf(12), "OnDragStop")
F.RunTimers()
expect(ns.model:GroupOf(12) == gB and not ns.Drag.Active(), "dropping a quest on a group's header moves it there")
dragTo(rowOf(12), yOf(rowOf(300)) + 2)
expect(ns.model:GroupOf(12) == gA and indexIn(gA, 12) == indexIn(gA, 300) - 1, "dropping on a row's top half puts it before")
dragTo(rowOf(12), yOf(rowOf(300)) + rowOf(300):GetHeight() - 2)
expect(indexIn(gA, 12) == indexIn(gA, 300) + 1, "and on its lower half after")
dragTo(groupOf(gB.name), yOf(groupOf(gA.name)) + 2)
expect(db.groups[1] == gB and db.groups[2] == gA, "a group dragged onto another's top half goes before it")
dragTo(groupOf(gA.name), yOf(groupOf(gB.name)) + 2)
expect(db.groups[1] == gA, "and back")
local function barIndex(id)
    for i, l in ipairs(tracker.lines) do
        if l.kind == "bar" and l.id == id then
            return i
        end
    end
end
dragTo(barOf("classprof"), yOf(barOf("world")) + 2)
expect(db.categoryOrder and barIndex("classprof") < barIndex("world"), "a category bar dragged in Journal reorders them")
db.categoryOrder = nil
local groupCount = #db.groups
-- Suivi's top reaches under the title, which takes no drop, so the pointer goes to the bar's middle.
dragTo(rowOf(1579), yOf(barOf("mine")) + barOf("mine"):GetHeight() / 2)
expect(#db.groups == groupCount + 1 and ns.model:GroupOf(1579) == db.groups[#db.groups] and tracker.frames.renameBox:IsShown(),
    "a quest dropped on Suivi starts a new group, named in place")
F.RunScript(tracker.frames.renameBox, "OnEscapePressed")
SlashCmdList.KALIQUEST("group del " .. db.groups[#db.groups].id)
F.RunTimers()
F.opened = nil
F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
F.cursorX, F.cursorY = 50, 1000 - 5000
F.RunScript(rowOf(1579), "OnDragStop")
F.RunScript(rowOf(1579), "OnClick", "LeftButton")
F.RunTimers()
expect(not ns.model:GroupOf(1579) and F.opened == nil, "dropped outside the groups, nothing happens, not even a click")
F.combat = true
errorsNow = #F.uiErrors
F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
expect(not ns.Drag.Active() and #F.uiErrors == errorsNow + 1, "a drag can't start in combat")
F.combat = false
F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
F.combat = true
F.Fire("PLAYER_REGEN_DISABLED")
expect(not ns.Drag.Active() and rowOf(1579):GetAlpha() == 1, "a fight starting cancels a drag")
F.RunScript(rowOf(1579), "OnDragStop")
F.combat = false
F.Fire("PLAYER_REGEN_ENABLED")
F.RunTimers()
expect(not ns.model:GroupOf(1579), "and its end drops nothing")
-- Searching or filtering, the player's groups stay, so a quest can still go into one (Ikar, 2026-11-11).
do
    if not search().open then
        click(search().searchButton)
    end
    expect(searchFor("rivetage") == "1579", "a search for one quest in the log")
    local header = groupOf(gB.name)
    expect(header and header:IsShown(), "leaves the player's groups shown, with no match in them")
    if header then
        dragTo(rowOf(1579), yOf(header) + 2)
    end
    expect(ns.model:GroupOf(1579) == gB, "and a quest dropped on one goes there")
    SlashCmdList.KALIQUEST("move 1579 0")
    F.RunScript(search().box, "OnEscapePressed")
    F.RunTimers()
    expect(not search().open and not ns.model:GroupOf(1579), "drag under a search: cleaned up")
end
do
    local before = list(gA)
    local first = rowOf(gA.quests[1])
    dragTo(first, yOf(first) + first:GetHeight() - 2)
    expect(list(gA) == before, "a quest dropped back on its own row stays where it was")
    local gBy = yOf(groupOf(gB.name))
    F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
    F.cursorX, F.cursorY = -3000, 1000 - (gBy + 2)
    F.RunScript(rowOf(1579), "OnDragStop")
    F.RunTimers()
    expect(not ns.model:GroupOf(1579), "dropped beside the tracker, at a group's height, nothing moves")
    local scrolled = tracker.frames.scroll.verticalScroll
    tracker.frames.scroll.verticalScroll = gBy + 20
    F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
    F.cursorX, F.cursorY = 50, 1000 - (gBy + 2)
    F.RunScript(rowOf(1579), "OnDragStop")
    F.RunTimers()
    tracker.frames.scroll.verticalScroll = scrolled
    expect(not ns.model:GroupOf(1579), "nor on a group scrolled away under the title")
    local framesBefore = #F.frames
    F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
    ns.RequestRefresh()
    F.RunTimers()
    ns.Drag.Update()
    expect(#F.frames == framesBefore, "a redraw during a drag reuses the groups' highlights")
    F.mouseDown = false
    ns.Drag.Update()
    F.mouseDown = nil
    F.RunTimers()
    expect(not ns.Drag.Active() and ns.model:GroupOf(1579) == gB, "released with no drag stop, as when the row was hidden, the drag still drops")
    SlashCmdList.KALIQUEST("move 1579 0")
    F.RunTimers()
end
-- Picking several quests with Ctrl+click: the menu and a drag then act on them all, in the order they show.
do
    local loose = {}
    for _, l in ipairs(tracker.lines) do
        if l.kind == "quest" and not l.group and not l.quest.leaving then
            loose[#loose + 1] = l.quest.id
        end
    end
    local p1, p2, p3 = loose[1], loose[2], loose[3]
    expect(p3 ~= nil, "pick setup: three quests in Journal")
    local function pickedRow(id)
        return rowOf(id) ~= nil and rowOf(id).Picked:IsShown()
    end
    F.opened = nil
    F.ctrl = true
    click(rowOf(p1))
    click(rowOf(p2))
    click(rowOf(p3))
    click(rowOf(p3))
    F.ctrl = nil
    expect(pickedRow(p1) and pickedRow(p2) and not pickedRow(p3) and F.opened == nil,
        "Ctrl+click picks a row and again unpicks it, opening nothing")
    expect(table.concat(ns.Rows.Picked(), ",") == p1 .. "," .. p2, "the picked quests, top to bottom")
    click(rowOf(p2), "RightButton")
    expect(F.lastMenu.items[1].text == "2 quêtes sélectionnées" and F.MenuItem("Suivre ces quêtes") and not F.MenuItem("Arrêter le suivi"),
        "a picked row's menu speaks for all of them")
    F.MenuItem(gB.name).choose()
    F.RunTimers()
    local n = #gB.quests
    expect(gB.quests[n - 1] == p1 and gB.quests[n] == p2 and F.watched[p1] and F.watched[p2], "Déplacer vers moves them all, in order, tracked")
    expect(pickedRow(p1) and pickedRow(p2), "they stay picked")
    click(rowOf(p1), "RightButton")
    F.MenuItem("Arrêter le suivi").choose()
    F.RunTimers()
    expect(not ns.model:GroupOf(p1) and not ns.model:GroupOf(p2) and not F.watched[p1] and not F.watched[p2],
        "Arrêter le suivi takes them all out")
    click(rowOf(p1), "RightButton")
    F.MenuItem("Suivre ces quêtes").choose()
    F.RunTimers()
    n = #db.groups[1].quests
    expect(db.groups[1].quests[n - 1] == p1 and db.groups[1].quests[n] == p2 and F.watched[p1] and F.watched[p2],
        "Suivre ces quêtes tracks them all into the top group")
    click(rowOf(p1), "RightButton")
    F.MenuItem("Arrêter le suivi").choose()
    F.RunTimers()
    F.RunScript(rowOf(p1), "OnDragStart", "LeftButton")
    local carried = ns.Drag.Active() and ns.Drag.Active().ids
    expect(carried and #carried == 2 and rowOf(p2):GetAlpha() == 0.4, "dragging a picked row carries and dims every picked one")
    F.cursorX, F.cursorY = 50, 1000 - (yOf(groupOf(gA.name)) + 2)
    F.RunScript(rowOf(p1), "OnDragStop")
    F.RunTimers()
    n = #gA.quests
    expect(gA.quests[n - 1] == p1 and gA.quests[n] == p2, "and drops them all, in order")
    local first = gA.quests[1]
    dragTo(rowOf(p2), yOf(rowOf(first)) + 2)
    expect(gA.quests[1] == p1 and gA.quests[2] == p2 and gA.quests[3] == first, "dropped on a row, they go before it, still in order")
    ns.model:MoveQuest(first, gA.id, 2)
    ns.RequestRefresh()
    F.RunTimers()
    dragTo(rowOf(p1), yOf(rowOf(p1)) + 2)
    expect(gA.quests[1] == p1 and gA.quests[2] == p2 and gA.quests[3] == first, "dropped on one of their own rows, they gather there")
    local fourth = gA.quests[4]
    expect(fourth ~= nil, "setup: a fourth quest in the group")
    dragTo(rowOf(p1), yOf(rowOf(fourth)) + 2)
    expect(gA.quests[1] == first and gA.quests[2] == p1 and gA.quests[3] == p2 and gA.quests[4] == fourth,
        "dropped further down, they land before that row, counted without themselves")
    local groups = #db.groups
    dragTo(rowOf(p1), yOf(barOf("mine")) + barOf("mine"):GetHeight() / 2)
    local newest = db.groups[#db.groups]
    expect(#db.groups == groups + 1 and list(newest) == p1 .. "," .. p2, "on Suivi's bar, they start a group together")
    F.RunScript(tracker.frames.renameBox, "OnEscapePressed")
    F.RunTimers()
    dragTo(rowOf(p3), yOf(groupOf(gB.name)) + 2)
    expect(ns.model:GroupOf(p3) == gB and list(newest) == p1 .. "," .. p2, "a row that isn't picked drags alone")
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    errorsNow = #F.uiErrors
    click(rowOf(p1), "RightButton")
    F.MenuItem(gB.name).choose()
    F.RunTimers()
    expect(ns.model:GroupOf(p1) == newest and #F.uiErrors == errorsNow + 1, "moving them is refused in combat")
    click(rowOf(p1))
    expect(#ns.Rows.Picked() == 0 and not pickedRow(p1), "any click without Ctrl lets them go")
    F.ctrl = true
    click(rowOf(p1))
    F.ctrl = nil
    expect(pickedRow(p1), "picking works in combat, as it moves nothing")
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    F.RunTimers()
    click(groupOf(newest.name))
    click(groupOf(newest.name))
    expect(#ns.Rows.Picked() == 0 and not pickedRow(p1), "a picked row that closes away is let go")
    SlashCmdList.KALIQUEST("group del " .. newest.id)
    SlashCmdList.KALIQUEST("move " .. p3 .. " 0")
    F.RunTimers()
end
-- A row fading out of the log: no item button, no drag, no click.
do
    db.open.categories.journal, db.open.categories.instances, db.open.headers["Les Mortemines"] = true, true, true
    ns.RequestRefresh()
    F.RunTimers()
    tracker.frames.scroll.top = 800
    rowOf(214).ItemSlot.left, rowOf(214).ItemSlot.top = 200, 790
    ns.Items.Sync()
    expect(ns.Items.Buttons()[214] ~= nil, "setup: 214's item has its button")
    local at214 = C_QuestLog.GetLogIndexForQuestID(214)
    local entry = F.entries[at214]
    removeFromLog(214)
    F.Fire("QUEST_REMOVED", 214)
    tracker.Refresh()
    local leaving = rowOf(214)
    expect(leaving and not ns.Items.Buttons()[214] and not leaving.ItemSlot:IsShown(), "a row fading out of the log keeps no item")
    F.opened = nil
    F.RunScript(leaving, "OnDragStart", "LeftButton")
    F.RunScript(leaving, "OnClick", "LeftButton")
    expect(not ns.Drag.Active() and F.opened == nil, "and can't be dragged or clicked")
    F.RunTimers()
    table.insert(F.entries, at214, entry)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    tracker.frames.scroll.top = nil
end
click(lock)
local lockFlashes = lock.Flash.plays or 0
F.RunScript(rowOf(1579), "OnDragStart", "LeftButton")
expect(not ns.Drag.Active() and (lock.Flash.plays or 0) == lockFlashes + 1, "locked, a drag doesn't start and the padlock flashes")
click(lock)
content.top, content.left = nil, nil

-- Review 3's fixes. The tracker's item buttons, first: shown over 214's row.
local function itemSetup()
    db.open.tracker = true
    ns.Menus.OpenParents(214)
    F.RunTimers()
    tracker.frames.scroll.top = 800
    rowOf(214).ItemSlot.left, rowOf(214).ItemSlot.top = 200, 790
    ns.Items.Sync()
    return ns.Items.Buttons()[214]
end
-- A tracker turned off in a fight can only clear its item buttons; they go once the fight ends.
do
    local b = itemSetup()
    expect(b and b:IsShown(), "setup: 214's item has its button")
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    F.RunTimers()
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    expect(b and b:IsShown() and b:GetAlpha() == 0, "a tracker turned off in a fight clears its item buttons")
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    F.RunTimers()
    expect(b and not b:IsShown() and not ns.Items.Buttons()[214] and not ns.Items.Watcher():IsShown(),
        "and they go once the fight ends, so none is left to click under Blizzard's tracker")
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    tracker.frames.scroll.top = nil
end
-- In a fight, a quest above 214 leaving the log moves it up; its button, not set up again, follows.
do
    local b = itemSetup()
    local at12, at214 = C_QuestLog.GetLogIndexForQuestID(12), C_QuestLog.GetLogIndexForQuestID(214)
    expect(b ~= nil and at12 and at214 and at12 < at214, "setup: 214 has a button and 12 sits above it in the log")
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    F.RunTimers()
    local e12 = F.entries[at12]
    table.remove(F.entries, at12)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    local asked
    GameTooltip.SetQuestLogSpecialItem = function(_, index)
        asked = index
    end
    if b then
        F.RunScript(b, "OnEnter")
    end
    GameTooltip.SetQuestLogSpecialItem = nil
    expect(asked ~= nil and asked == C_QuestLog.GetLogIndexForQuestID(214),
        "in a fight, an item button's tooltip reads its own quest's place in the log: asked " .. tostring(asked))
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    table.insert(F.entries, at12, e12)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    tracker.frames.scroll.top = nil
end
-- The tracker moving with no layout, as the right-hand frames push it down, takes the item buttons along.
do
    local b = itemSetup()
    KaLiQuestTracker.left, KaLiQuestTracker.top = 150, 850
    ns.Items.Sync()
    local watcher = ns.Items.Watcher()
    expect(b and b.top == 790 and watcher:IsShown(), "setup: 214's button over its slot, and the check runs while buttons show")
    KaLiQuestTracker.top, tracker.frames.scroll.top, rowOf(214).ItemSlot.top = 820, 770, 760
    F.RunScript(watcher, "OnUpdate", 0.25)
    expect(b and b.top == 760, "a tracker moved with no layout lines its item buttons up again: " .. tostring(b and b.top))
    KaLiQuestTracker.left, KaLiQuestTracker.top, tracker.frames.scroll.top = nil, nil, nil
    rowOf(214).ItemSlot.left, rowOf(214).ItemSlot.top = nil, nil
    ns.RequestRefresh()
    F.RunTimers()
end

-- Coming back after Blizzard's tracker showed, nothing that happened meanwhile replays: a quest that left doesn't
-- fade again, progress doesn't glow, nor teach the area highlight where the player now stands.
do
    local id = 12
    local was, wasIndex = ns.model:GroupOf(id)
    if was then
        ns.model:MoveQuest(id, nil)
    end
    ns.Menus.OpenParents(id)
    F.RunTimers()
    expect(rowOf(id) ~= nil, "setup: 12 drawn in Journal")
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    local at = C_QuestLog.GetLogIndexForQuestID(id)
    local entry = F.entries[at]
    removeFromLog(id)
    F.Fire("QUEST_REMOVED", id)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    SlashCmdList.KALIQUEST("tracker on")
    expect(not rowOf(id), "a quest that left the log while Blizzard's tracker showed doesn't come back to fade")
    F.RunTimers()
    table.insert(F.entries, at, entry)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    if was then
        ns.model:MoveQuest(id, was.id, wasIndex)
        F.RunTimers()
    end

    local highlight = db.options.areaHighlight
    db.options.areaHighlight = true
    id = 1579
    local e = F.entries[C_QuestLog.GetLogIndexForQuestID(id)]
    local objectives = e.objectives
    e.objectives = { { text = "Rouages : 1/5", finished = false, count = 1 } }
    F.playerPos = { 0.1, 0.1 }
    ns.Menus.OpenParents(id)
    F.RunTimers()
    db.spots[id] = nil
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    e.objectives = { { text = "Rouages : 4/5", finished = true, count = 5 } }
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    F.playerPos = { 0.9, 0.9 }
    local glows = plays("row", "ProgressGlow") + plays("group", "Flash") + plays("bar", "Flash")
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    expect(rowOf(id) and plays("row", "ProgressGlow") + plays("group", "Flash") + plays("bar", "Flash") == glows,
        "progress made while Blizzard's tracker showed doesn't glow when KaLi Quest's comes back")
    expect(not db.spots[id], "nor is it learnt where the player stands then")
    e.objectives, db.spots[id], F.playerPos, db.options.areaHighlight = objectives, nil, nil, highlight
    ns.Area.Apply()
    ns.RequestRefresh()
    F.RunTimers()

    -- Achievements: one earned meanwhile doesn't play its turn-in; one tracked meanwhile doesn't slide in, nor its new
    -- bar fade in.
    F.achievementInfo[504] = { name = "Déjà là", description = "Deux", criteria = { { text = "Deux" } } }
    F.achievements = { 504 }
    F.Fire("CONTENT_TRACKING_UPDATE", 2, 504, true)
    F.RunTimers()
    expect(barOf("achievements") ~= nil, "setup: 504 drawn under its bar")
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    F.achievementInfo[504].earned = true
    F.Fire("ACHIEVEMENT_EARNED", 504)
    F.achievements = {}
    F.RunTimers()
    local turnIns = plays("entry", "FadeOut")
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    expect(plays("entry", "FadeOut") == turnIns and not barOf("achievements"),
        "an achievement earned while Blizzard's tracker showed doesn't play its turn-in when KaLi Quest's comes back")
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    F.achievementInfo[503] = { name = "Pendant l'absence", description = "Un", criteria = { { text = "Un" } } }
    F.achievements = { 503 }
    local sweeps, barFades = plays("entry", "HeadSweep"), plays("bar", "FadeIn")
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    expect(barOf("achievements") and plays("entry", "HeadSweep") == sweeps and plays("bar", "FadeIn") == barFades,
        "one tracked meanwhile doesn't slide in, nor does its new bar fade in")
    F.achievements, F.achievementInfo[503], F.achievementInfo[504] = {}, nil, nil
    ns.RequestRefresh()
    F.RunTimers()

    -- A quest accepted in a fight while Blizzard's tracker showed, KaLi Quest's coming back in that fight, shows at once.
    SlashCmdList.KALIQUEST("tracker off")
    F.RunTimers()
    F.combat = true
    F.Fire("PLAYER_REGEN_DISABLED")
    table.insert(F.entries, 2, quest(603, "Pendant le combat, ailleurs"))
    F.Fire("QUEST_ACCEPTED", 603)
    ns.Menus.OpenParents(603)
    F.RunTimers()
    SlashCmdList.KALIQUEST("tracker on")
    F.RunTimers()
    expect(rowOf(603) ~= nil, "a quest accepted in the fight before KaLi Quest's came back isn't held back for its end")
    F.combat = false
    F.Fire("PLAYER_REGEN_ENABLED")
    removeFromLog(603)
    F.Fire("QUEST_REMOVED", 603)
    F.RunTimers()
end

-- Menus and chat lines.
do
    local g = db.groups[1]
    if #g.quests < 2 then
        ns.model:MoveQuest(1579, g.id)
        ns.model:MoveQuest(214, g.id)
    end
    db.open.tracker, db.open.categories.mine, db.open.groups[g.id] = true, true, true
    ns.RequestRefresh()
    F.RunTimers()
    local before = list(g)
    local r = rowOf(g.quests[1])
    expect(r ~= nil and #g.quests >= 2, "setup: the top group's first quest is drawn, with another after it")
    if r then
        click(r, "RightButton")
        local item = F.MenuItem(g.name)
        expect(item and item.kind == "radio" and item.isSelected(), "setup: its group is the ticked entry of Déplacer vers")
        if item then
            item.choose()
        end
        F.RunTimers()
    end
    expect(list(g) == before,
        "choosing its own group in Déplacer vers leaves the quest in place: " .. before .. " -> " .. list(g))

    local was, wasIndex = ns.model:GroupOf(12)
    SlashCmdList.KALIQUEST("group new Sonde")
    F.RunTimers()
    local probe = db.groups[#db.groups]
    ns.model:MoveQuest(12, probe.id)
    ns.RequestRefresh()
    F.RunTimers()
    F.popup = nil
    click(groupOf(probe.name), "RightButton")
    F.MenuItem(ns.L.DELETE_GROUP).choose()
    expect(F.popup ~= nil, "setup: deleting a group holding a quest asks first")
    SlashCmdList.KALIQUEST("group del " .. probe.id)
    F.RunTimers()
    local said = #F.printed
    if F.popup then
        F.AcceptPopup()
    end
    F.RunTimers()
    local line = F.printed[said + 1] or ""
    expect(line:find(ns.L.GROUP_GONE, 1, true) and not line:find("missing", 1, true),
        "accepting the delete question once the group has gone says so in words: " .. line)
    ns.model.deleted = nil
    if was then
        ns.model:MoveQuest(12, was.id, wasIndex)
    end

    local saved, disabled = ns.db, ns.disabled
    ns.db, ns.disabled = nil, "test"
    said = #F.printed
    KaLiQuest_OnAddonCompartmentClick()
    ns.db, ns.disabled = saved, disabled
    expect((F.printed[said + 1] or ""):find("(test)", 1, true), "with the saved data refused, the compartment's click says why")

    local errors = KaLiQuestDevDB.errors
    KaLiQuestDevDB.errors = {
        ["old, often"] = { count = 10, first = "2026-11-09 10:00:00", last = "2026-11-09 10:00:00" },
        ["new, twice"] = { count = 2, first = "2026-11-09 11:00:00", last = "2026-11-09 11:00:00" },
        ["new, once"] = { count = 1, first = "2026-11-09 11:00:00", last = "2026-11-09 11:00:00" },
    }
    local text = ns.Debug.ErrorsText()
    KaLiQuestDevDB.errors = errors
    local twice, once = text:find("new, twice", 1, true), text:find("new, once", 1, true)
    local often = text:find("old, often", 1, true)
    expect(twice and once and often and twice < once and once < often, "/kq errors lists the latest first, then the most frequent")

    local tips = {}
    for _, s in ipairs(ns.L.TIPS) do
        for _, row in ipairs(s.rows) do
            tips[row[1]] = row[2]
        end
    end
    expect(not tips.Clic:find("lien", 1, true) and tips["Maj+clic"]:find("lien", 1, true),
        "Astuces: a link goes into chat on Maj+clic, as ChatFrameUtil.TryInsertChatLink wants the link modifier")
    expect(tips["Flèche dorée"] and not tips["Flèche dorée"]:find("fermé", 1, true), "Astuces: the area count shows on open headers too")
end

-- Clicking a finished auto-complete quest's row opens its turn-in and takes its popup away, as Blizzard's.
do
    local id = 1579
    local e = F.entries[C_QuestLog.GetLogIndexForQuestID(id)]
    e.isAutoComplete, e.complete = true, true
    F.popups = { { questID = id, type = "COMPLETE" } }
    ns.Menus.OpenParents(id)
    F.RunTimers()
    F.shownComplete = nil
    local r = rowOf(id)
    expect(r ~= nil, "setup: 1579's row drawn")
    if r then
        click(r)
    end
    expect(F.shownComplete == id and #F.popups == 0, "clicking a finished auto-complete quest's row takes its popup away")
    e.isAutoComplete, e.complete, F.popups = nil, nil, {}
    ns.RequestRefresh()
    F.RunTimers()
end

-- An abandoned quest leaves its group at once, Ikar's ruling on 2026-11-09. A daily turned in keeps its place, even
-- when the turn-in comes after the quest left the log.
do
    local g = db.groups[1]
    local id = 1579
    local was, wasIndex = ns.model:GroupOf(id)
    ns.model:MoveQuest(id, g.id)
    F.RunTimers()
    local at = C_QuestLog.GetLogIndexForQuestID(id)
    local entry = F.entries[at]
    removeFromLog(id)
    F.Fire("QUEST_REMOVED", id)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    expect(not ns.model:GroupOf(id), "an abandoned quest leaves its group at once")
    table.insert(F.entries, at, entry)
    F.Fire("QUEST_ACCEPTED", id)
    F.RunTimers()
    expect(not ns.model:GroupOf(id), "accepted again, it stays in Journal")
    F.entries[#F.entries + 1] = quest(700, "Quotidienne bis", { frequency = 1 })
    F.Fire("QUEST_ACCEPTED", 700)
    F.RunTimers()
    ns.model:MoveQuest(700, g.id)
    F.RunTimers()
    removeFromLog(700)
    F.Fire("QUEST_REMOVED", 700)
    F.Fire("QUEST_TURNED_IN", 700, 0, 0)
    F.Fire("QUEST_LOG_UPDATE")
    F.RunTimers()
    expect(ns.model:GroupOf(700) == g, "a daily turned in keeps its place, its turn-in coming second")
    ns.model:MoveQuest(700, nil)
    C_QuestLog.RemoveQuestWatch(700)
    db.repeatable[700] = nil
    if was then
        ns.model:MoveQuest(id, was.id, wasIndex)
    else
        C_QuestLog.RemoveQuestWatch(id)
    end
    ns.RequestRefresh()
    F.RunTimers()
end

-- The diagnostics panel outgrows its room with debug on, so its lines scroll above its buttons.
do
    KaLiQuestDevDB.debug = true
    for i = 1, 30 do
        ns.Debug.Log("smoke", "une ligne du journal, la %de, assez longue pour ressembler à une vraie ligne du suivi", i)
    end
    SlashCmdList.KALIQUEST("diag")
    local panel = ns.DebugPanel.Frames()
    F.RunScript(panel, "OnUpdate", 1)
    expect(#ns.DebugPanel.Lines() > 40, "setup: with debug on, the panel has more than the 40 lines it has room for")
    expect(panel.Scroll and panel.Scroll.scrollChild == panel.Content and panel.Content.fontStrings[1] == panel.Body
        and panel.Content:GetHeight() >= panel.Body:GetStringHeight(),
        "every line of the diagnostics panel is in its scrolling part, however many there are")
    SlashCmdList.KALIQUEST("diag")
    KaLiQuestDevDB.debug = false
end

-- The options page: each section with settings ends with a reset row, which puts back that section's settings only.
do
    local sections = { { name = "haut de page", settings = {} } }
    local resets = 0
    for _, init in ipairs(F.settingsLayout.initializers) do
        if init.header then
            sections[#sections + 1] = { name = init.header, settings = {} }
        end
        local s = sections[#sections]
        if init.setting then
            s.settings[#s.settings + 1] = init.setting
        elseif init.buttonText == "Réinitialiser" then
            s.reset = init
            resets = resets + 1
        end
        s.last = init
    end
    local wrong = {}
    for _, s in ipairs(sections) do
        if not (#s.settings == 0 and not s.reset or #s.settings > 0 and s.reset and s.last == s.reset
            and s.reset.name == "Valeurs par défaut" and s.reset.tooltip) then
            wrong[#wrong + 1] = s.name
        end
    end
    expect(resets == 1 and #wrong == 0, "the options page's one section with settings ends with a reset row, the others have none: "
        .. table.concat(wrong, ", "))

    local before = ns.DeepCopy(db.options)
    local function offDefault(setting)
        local d = setting:GetDefaultValue()
        if type(d) == "boolean" then
            return not d
        elseif type(d) == "number" then
            return d + 1
        end
        for _, choice in ipairs(setting.options()) do
            if choice.value ~= d then
                return choice.value
            end
        end
    end
    local function allAt(s, atDefault)
        for _, setting in ipairs(s.settings) do
            if (setting:GetValue() == setting:GetDefaultValue()) ~= atDefault then
                return false
            end
        end
        return true
    end
    local withReset = {}
    for _, s in ipairs(sections) do
        if s.reset then
            withReset[#withReset + 1] = s
            for _, setting in ipairs(s.settings) do
                setting:SetValue(offDefault(setting))
            end
        end
    end
    F.RunTimers()
    expect(not tracker.IsActive() and F.cvars.autoQuestWatch == "1", "setup: every setting off its default")
    local leaks = {}
    for i, s in ipairs(withReset) do
        s.reset.buttonClick()
        F.RunTimers()
        for j, other in ipairs(withReset) do
            if not allAt(other, j <= i) then
                leaks[#leaks + 1] = s.name .. " > " .. other.name
            end
        end
    end
    expect(#leaks == 0, "each reset row puts back its own section's settings, and no other's: " .. table.concat(leaks, ", "))
    expect(tracker.IsActive() and F.cvars.autoQuestWatch == "0", "and what they drive follows: KaLi Quest's tracker back, auto-tracking off")

    F.filled.ScenarioObjectiveTracker = true
    F.UpdateSections()
    F.RunTimers()
    expect(not tracker.IsActive(), "setup: a scenario puts KaLi Quest's tracker aside")
    F.settingsCategory.settings.KALIQUEST_AUTOQUESTWATCH:SetValue(true)
    withReset[1].reset.buttonClick()
    F.RunTimers()
    expect(db.options.autoQuestWatch == false and not tracker.IsActive(),
        "a reset leaves alone a tracker switch already on, so the tracker stays aside for the scenario")
    F.filled.ScenarioObjectiveTracker = nil
    F.UpdateSections()
    F.RunTimers()

    local markers = db.options.markers
    for key in pairs(db.options) do
        db.options[key] = nil
    end
    for key, value in pairs(before) do
        db.options[key] = value
    end
    db.options.markers = markers
    for kind, on in pairs(before.markers) do
        markers[kind] = on
    end
    ns.RequestRefresh()
    F.RunTimers()
    expect(tracker.IsActive(), "setup: the options as they were, KaLi Quest's tracker back")
end

-- The bug report: the gear's last line, a row on the options page and /kq report open it, and its one button selects
-- a report holding everything, for Ctrl+C. What the addon takes from the game is looked for at login and in a report.
do
    local checks = KaLiQuestDevDB.apiChecks or {}
    local atLogin = checks[#checks]
    -- The fake has every atlas, event and template; of globals, CVars and game strings, only what the smoke test uses.
    local wrong = {}
    for _, m in ipairs(atLogin and atLogin.missing or {}) do
        if not (m:find("^global ") or m:find("^cvar ") or m:find("^string ")) or m == "global C_QuestLog.GetInfo"
            or m == "global CreateFrame" then
            wrong[#wrong + 1] = m
        end
    end
    expect(atLogin and atLogin.build == select(2, GetBuildInfo()) and atLogin.checked > 200 and #wrong == 0,
        "at login, the addon looked for what it takes from the game and kept the result for this build: "
        .. table.concat(wrong, ", "))
    expect(table.concat(ns.DebugPanel.Lines(), "\n"):find("API du jeu : ", 1, true), "the diagnostics panel says how that went")
    local errNotInCombat = ERR_NOT_IN_COMBAT
    ERR_NOT_IN_COMBAT = nil
    local run = ns.SelfCheck.Run()
    ERR_NOT_IN_COMBAT = errNotInCombat
    expect(#ns.NEEDS.strings > 40 and table.concat(run.missing, ","):find("string ERR_NOT_IN_COMBAT", 1, true),
        "it looks for the game strings the addon shows too")

    -- What the addon assumes of the game is tried on the game itself: at login once the log has loaded, at each zone
    -- change and in each report. On the fake all holds, but for its headers having no key.
    local function record(list, name)
        for _, a in ipairs(list or {}) do
            if a.name == name then
                return a
            end
        end
    end
    local tried = {}
    for _, a in ipairs(atLogin and atLogin.assumed or {}) do
        tried[#tried + 1] = a.name
    end
    local headersAtLogin = record(atLogin and atLogin.assumed, "log headers")
    expect(table.concat(tried, ",") == "log headers,log listing,game numbers,zone name,settings,frames,tracking limit"
        and headersAtLogin and headersAtLogin.looked > 0,
        "at login, once the log had loaded, it tried each thing it assumes and kept them for the build: "
        .. table.concat(tried, ","))
    local function now(name)
        return record((ns.SelfCheck.Assumptions()), name)
    end
    local function problems(name)
        local a = now(name)
        return a and table.concat(a.wrong, " | ") or "missing"
    end
    for _, name in ipairs({ "log listing", "game numbers", "zone name", "settings", "frames" }) do
        local a = now(name)
        expect(a and a.looked > 0 and #a.wrong == 0, name .. " holds on the fake: " .. problems(name))
    end
    expect(now("log listing").note == "0 headers collapsed in the game's log", "the listing says how many headers the game's log has collapsed")
    local weekly = Enum.QuestFrequency.Weekly
    Enum.QuestFrequency.Weekly = 5
    expect(problems("game numbers") == "Enum.QuestFrequency.Weekly is 5, the addon reads 2",
        "a game number the addon reads that moved is named: " .. problems("game numbers"))
    Enum.QuestFrequency.Weekly = weekly
    local tagConsts = Constants.QuestConsts
    Constants.QuestConsts = nil
    expect(problems("game numbers"):find("Constants.QuestConsts.QUEST_INFO_DUNGEON_ID is nil, the addon reads 81", 1, true),
        "and one the game no longer has")
    Constants.QuestConsts = tagConsts
    local count = C_QuestLog.GetNumQuestLogEntries
    C_QuestLog.GetNumQuestLogEntries = function()
        local entries, quests = count()
        return entries, quests + 2
    end
    expect(problems("log listing"):find("quests listed of", 1, true), "quests the log's rows leave out are counted")
    C_QuestLog.GetNumQuestLogEntries = count
    F.modifiedClicks.QUESTWATCHTOGGLE = "ALT"
    expect(problems("settings") == "QUESTWATCHTOGGLE is ALT, not SHIFT", "a tracking key other than Shift is named")
    F.modifiedClicks.QUESTWATCHTOGGLE = nil
    local cvarInfo = C_CVar.GetCVarInfo
    C_CVar.GetCVarInfo = function(name)
        local value, default, account, character = cvarInfo(name)
        return value, default, account, character, false, true, false
    end
    expect(problems("settings"):find("autoQuestWatch: value ", 1, true) and problems("settings"):find("secure true", 1, true),
        "and an auto-tracking setting an addon can't set")
    C_CVar.GetCVarInfo = cvarInfo
    ObjectiveTrackerFrame.IsProtected = function()
        return true
    end
    expect(problems("frames") == "ObjectiveTrackerFrame is protected", "a protected tracker frame is named")
    ObjectiveTrackerFrame.IsProtected = nil
    F.mapID, F.zoneText = 1439, "Sombrivage"
    F.Fire("ZONE_CHANGED_NEW_AREA")
    F.mapID, F.zoneText = nil, nil
    local zone = record(checks[#checks].assumed, "zone name")
    expect(zone and zone.looked == 2 and table.concat(zone.wrong, " | ")
        == "area 148 is named Sombrivage (Darkshore), GetZoneText() says Sombrivage",
        "a zone whose name isn't its area's is named, and kept for the build at the zone change: " .. problems("zone name"))
    local addWatch = C_QuestLog.AddQuestWatch
    C_QuestLog.AddQuestWatch = function()
        return false
    end
    ns.Tracking.World:AddWatch(12)
    C_QuestLog.AddQuestWatch = addWatch
    local limit = record(checks[#checks].assumed, "tracking limit")
    expect(limit and limit.looked >= 1 and table.concat(limit.wrong, " | "):find("AddQuestWatch(12) refused with ", 1, true),
        "a refusal under the game's 25 is named, and kept for the build")
    local all, failing = ns.SelfCheck.Assumptions()
    local sum = 0
    for _, a in ipairs(all) do
        sum = sum + #a.wrong
    end
    expect(failing == sum and sum >= 2 and checks[#checks].failing == sum, "what doesn't hold is counted in all: " .. tostring(failing))

    click(gear)
    local items = F.lastMenu and F.lastMenu.items or {}
    local last = items[#items]
    expect(last and last.text == "Signaler un bug", "the gear's menu ends with Signaler un bug")
    if last then
        last.choose()
    end
    local frame = ns.Report.Frame()
    expect(frame and frame:IsShown() and frame.TitleContainer.TitleText:GetText() == "Signaler un bug", "which opens its window")
    local text = frame and frame.Box:GetText() or ""
    local absent = {}
    for _, part in ipairs({ "status", "api check", "errors", "game warnings", "diagnostics", "options", "groups", "tree",
        "addons", "tests", "log" }) do
        if not text:find("== " .. part .. " ==", 1, true) then
            absent[#absent + 1] = part
        end
    end
    expect(#absent == 0 and not text:find("(failed", 1, true) and not text:find("|c", 1, true),
        "the report holds every part, none failed, in plain text: " .. table.concat(absent, ", "))
    expect(text:find("assumptions: 7 tried, ", 1, true) and text:find("\n  log headers: looked at ", 1, true)
        and text:find([[not as assumed: header "Marche de l'Ouest": key nil]], 1, true)
        and text:find("\n  zone name: looked at 2\n    not as assumed: area 148", 1, true),
        "its API check lists each assumption it tried, with what didn't hold")
    local g1 = db.groups[1]
    expect(text:find("KaLiQuest 0.1.0-test", 1, true) and text:find("Spoken 0.1.0-test", 1, true)
        and text:find("WARRIOR, level 23", 1, true) and g1 and text:find(g1.name, 1, true)
        and (not g1.quests[1] or text:find("#" .. g1.quests[1] .. " ", 1, true)),
        "with the addons loaded, the character's class and level, and the groups with their quests")
    local issue = "https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new?title=KaLi%20Quest%200.1.0-test%3A%20&body="
    local shown = frame.URL:GetText()
    expect(frame.URL:IsShown() and not frame.NoURL:IsShown() and shown:sub(1, #issue) == issue
        and shown:find("Collez%20le%20rapport%20ici", 1, true) and not shown:find("status", 1, true),
        "it shows a link to the repository's new issue, saying where to paste the report, without the report")

    F.focus = nil
    click(frame.Copy)
    expect(F.focus == frame.Box and frame.Box.highlighted and frame.Hint:GetText() == "Ctrl+C pour copier",
        "its button selects the whole report, for Ctrl+C")
    local selected = frame.Box:GetText()
    frame.Box:SetText("abc")
    F.RunScript(frame.Box, "OnTextChanged", true)
    expect(frame.Box:GetText() == selected and frame.Box.highlighted, "typing in it changes nothing")
    F.ctrl = true
    F.RunScript(frame.Box, "OnKeyDown", "C")
    F.ctrl = false
    F.RunTimers()
    expect(F.focus ~= frame.Box and frame.Hint:GetText() == "Copié : collez-le dans le ticket.",
        "after Ctrl+C the box lets go of the keyboard and says what to do next")

    local url, shownLink = ns.Report.URL, frame.URL:GetText()
    frame.URL:SetText("x")
    F.RunScript(frame.URL, "OnTextChanged", true)
    expect(frame.URL:GetText() == shownLink, "typing in the link's box changes nothing either")
    ns.Report.URL = nil
    ns.Report.Open()
    expect(frame.NoURL:IsShown() and not frame.URL:IsShown(), "with no address, it says one is to come")
    ns.Report.URL = url

    -- What a patch could take away: an atlas, an event, a function. A Blizzard addon not loaded hides nothing.
    local superTrack = C_SuperTrack.SetSuperTrackedQuestID
    F.missingAtlases["communities-icon-lock"] = true
    F.invalidEvents.QUEST_LOG_UPDATE = true
    C_SuperTrack.SetSuperTrackedQuestID = nil
    local achievements = AchievementFrame_LoadUI
    AchievementFrame_LoadUI = nil
    F.notLoaded.Blizzard_AchievementUI = true
    F.Fire("ADDON_ACTION_BLOCKED", "KaLiQuest", "UseQuestLogSpecialItem()")
    F.Fire("ADDON_ACTION_BLOCKED", "KaLiQuest", "UseQuestLogSpecialItem()")
    F.Fire("ADDON_ACTION_FORBIDDEN", "AutreAddon", "CastSpellByName()")
    F.Fire("LUA_WARNING", "Interface/AddOns/KaLiQuest/UI/Rows.lua:12: something deprecated")
    F.Fire("LUA_WARNING", "Interface/AddOns/KaLiQuest_Tests/Run.lua:3: not the addon's")
    table.insert(KaLiQuestDevDB.apiChecks, 1, { build = "70700", version = "0.1.0", when = "2026-11-01 20:00", checked = 300,
        missing = { "atlas old-gone" } })
    ns.Report.Open()
    text = frame.Box:GetText()
    table.remove(KaLiQuestDevDB.apiChecks, 1)
    F.missingAtlases["communities-icon-lock"] = nil
    F.invalidEvents.QUEST_LOG_UPDATE = nil
    C_SuperTrack.SetSuperTrackedQuestID = superTrack
    AchievementFrame_LoadUI = achievements
    F.notLoaded.Blizzard_AchievementUI = nil
    expect(text:find("missing: atlas communities-icon-lock", 1, true) and text:find("missing: event QUEST_LOG_UPDATE", 1, true)
        and text:find("missing: global C_SuperTrack.SetSuperTrackedQuestID", 1, true)
        and not text:find("AchievementFrame_LoadUI", 1, true),
        "the report names what the game no longer has, but not what a Blizzard addon not yet loaded holds")
    expect(text:find("blocked  x2  UseQuestLogSpecialItem()", 1, true) and text:find("Rows.lua:12", 1, true)
        and not text:find("CastSpellByName", 1, true) and not text:find("not the addon's", 1, true),
        "and what the game blocked or warned about in the addon, counted, nothing of other addons'")
    expect(text:find("since build 70700: newly missing atlas communities-icon-lock", 1, true)
        and text:find("; back atlas old-gone", 1, true), "and what changed since the last other build seen")

    local db, disabled = ns.db, ns.disabled
    ns.db, ns.disabled = nil, "version 9 > 1"
    local refused = ns.Report.Text()
    ns.db, ns.disabled = db, disabled
    expect(refused:find("(no saved data: version 9 > 1)", 1, true) and not refused:find("(failed", 1, true),
        "with the saved data refused, the report still comes, and says why")
    local tree = ns.Commands.TreeText
    ns.Commands.TreeText = function()
        error("cassé")
    end
    local broken = ns.Report.Text()
    ns.Commands.TreeText = tree
    expect(broken:find("== tree ==\n(failed: ", 1, true) and broken:find("cassé", 1, true) and broken:find("== log ==", 1, true),
        "a part that fails says so, and the parts after it still come")
    local log = KaLiQuestDevDB.log
    KaLiQuestDevDB.log = {}
    for i = 1, 100 do
        KaLiQuestDevDB.log[i] = string.rep("x", 990) .. i
    end
    local long = ns.Report.Text()
    KaLiQuestDevDB.log = log
    expect(#long <= 60100 and long:find("(cut at 60000 characters)", 1, true) and long:find("== errors ==", 1, true),
        "a report too long for an issue loses its end")

    frame:Hide()
    local row
    for _, init in ipairs(F.settingsLayout.initializers) do
        if init.name == "Signaler un bug" then
            row = init
        end
    end
    expect(row and row.buttonText == "Ouvrir", "the options page has a row for it")
    if row then
        row.buttonClick()
    end
    expect(frame:IsShown(), "which opens the same window")
    frame:Hide()
    SlashCmdList.KALIQUEST("report")
    expect(frame:IsShown(), "and so does /kq report")
    frame:Hide()

    -- What doesn't hold, or is missing but for a game string, is said once in chat per build and addon version.
    local function told()
        local n = 0
        for _, line in ipairs(F.printed) do
            if line:find("/kq report pour le signaler", 1, true) then
                n = n + 1
            end
        end
        return n
    end
    expect(told() == 1 and checks[#checks].told == true, "what doesn't hold on the fake was said once in chat, with how to report it: "
        .. told())
    ns.SelfCheck.AtLogin()
    F.Fire("ZONE_CHANGED_NEW_AREA")
    expect(told() == 1 and checks[#checks].told == true, "and not again at the next login of the same build and version")
    local assumptions, entry = ns.SelfCheck.Assumptions, checks[#checks]
    local missing, failing = entry.missing, 0
    ns.SelfCheck.Assumptions = function()
        return {}, failing
    end
    entry.told, entry.missing = nil, { "string ERR_NOT_IN_COMBAT" }
    F.Fire("ZONE_CHANGED_NEW_AREA")
    expect(told() == 1, "a game string missing alone isn't said: the addon has its own wording for it")
    entry.missing = { "atlas communities-icon-lock" }
    F.Fire("ZONE_CHANGED_NEW_AREA")
    expect(told() == 2, "anything else missing is")
    entry.told, entry.missing, failing = nil, {}, 1
    F.Fire("ZONE_CHANGED_NEW_AREA")
    expect(told() == 3, "and so is an assumption that doesn't hold")
    entry.missing = missing
    ns.SelfCheck.Assumptions = assumptions
    local buildInfo = GetBuildInfo
    GetBuildInfo = function()
        local version, _, date, interface = buildInfo()
        return version, "99999", date, interface
    end
    ns.SelfCheck.AtLogin()
    F.Fire("ZONE_CHANGED_NEW_AREA")
    GetBuildInfo = buildInfo
    expect(told() == 4, "and it's said again for another build")
    for i = #checks, 1, -1 do
        if checks[i].build == "99999" then
            table.remove(checks, i)
        end
    end
    ns.SelfCheck.AtLogin()
    F.Fire("ZONE_CHANGED_NEW_AREA")
    expect(told() == 4 and checks[#checks].build == select(2, GetBuildInfo()), "setup: back to this build, already said")
end

-- Each window of the addon shows Blizzard's red X over all its parts, and closes with Escape.
do
    ns.DebugPanel.Open()
    ns.Debug.ShowText("x", "x")
    ns.Report.Open()
    for _, name in ipairs({ "KaLiQuestDebugPanel", "KaLiQuestTextWindow", "KaLiQuestReport" }) do
        local window, close, top = _G[name], nil, 0
        for _, part in ipairs(window and { window:GetChildren() } or {}) do
            if part.template == "UIPanelCloseButton" then
                close = part
            else
                top = math.max(top, part:GetFrameLevel())
            end
        end
        local escape = false
        for _, special in ipairs(UISpecialFrames) do
            escape = escape or special == name
        end
        local level = close and close:GetFrameLevel() or -1
        expect(close and close:IsShown() and level > window:GetFrameLevel() and level >= top and escape,
            name .. ": its red X shows over all its parts, and Escape closes it")
        if window then
            window:Hide()
        end
    end
    F.focus = nil
end

-- The probe: its passive checks ran after login. Now every command, then its report must hold no failed check.
local layout = list(db.groups[1]) .. "|" .. list(db.groups[2])
for _, cmd in ipairs({ "", "run", "park", "unpark", "row", "item", "watch", "collapse", "hide", "show" }) do
    SlashCmdList.KQPROBE(cmd)
    F.RunTimers()
end
KaLiQuestProbeItem.scripts.OnClick()
F.RunTimers()
expect(F.usedItem ~= nil, "the probe's item button used the quest item")
F.menus.MENU_QUEST_MAP_LOG_TITLE({ questID = 12, GetObjectType = function()
    return "Button"
end, GetName = function() end }, nil, { questID = 12 })
for _, name in ipairs({ "environment", "protected", "sections", "log", "quests", "cvars", "atlases", "functions", "park", "row", "item",
    "watch", "collapse", "menus" }) do
    local c = KaLiQuestProbeDB.checks[name]
    expect(c ~= nil, "probe check ran: " .. name)
    if c and c.ok == false then
        failures[#failures + 1] = "probe check " .. name .. " failed: " .. tostring(c.lines[#c.lines])
    end
end
expect(list(db.groups[1]) .. "|" .. list(db.groups[2]) == layout, "the probe's watch test leaves the layout as it was")
SlashCmdList.KQPROBE("reset")

-- A nan that reached the options, as the game's Lua lets one through, isn't written: the file would no longer read.
db.options.editModeHeight = 0 / 0
F.Fire("PLAYER_LOGOUT")
expect(F.cvars.autoQuestWatch == "1", "the game's own auto-tracking is put back at logout")
expect(db.options.autoQuestWatch == false, "putting it back doesn't change the player's choice")
expect(db.options.editModeHeight == nil and db.nonFinite == 1, "at logout, the number the file can't hold is taken out")

local errorCount = 0
for msg in pairs(KaLiQuestDevDB.errors) do
    errorCount = errorCount + 1
    failures[#failures + 1] = "error: " .. msg
end
expect(#F.errors == errorCount, "every error also went to the game's error handler")
return failures
