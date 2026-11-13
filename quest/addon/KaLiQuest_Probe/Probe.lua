-- KaLi Quest probe, build step 1: answers the plan's in-game risks before the tracker is written.
-- Passive checks run by themselves after login and change nothing. Active tests run only on command, and
-- /kqprobe unpark undoes the one that moves Blizzard's frames. Everything is saved in KaLiQuestProbeDB.
local ADDON = ...

local db
local current
local session = { blocked = {}, cvarTimeline = {} }

local function now()
    return date("%Y-%m-%d %H:%M:%S")
end

-- autoQuestWatch at each step of the login, to see when the game's own copy arrives.
local function noteCVar(moment)
    local timeline = session.cvarTimeline
    timeline[#timeline + 1] = string.format("t=%.3f %s: autoQuestWatch %s", GetTime(), moment, tostring(GetCVar("autoQuestWatch")))
end

local function say(msg)
    print("|cffffd200KaLi Quest probe :|r " .. tostring(msg))
end

local function show(v, depth)
    depth = depth or 0
    if type(v) == "string" then
        return string.format("%q", v)
    elseif type(v) == "table" and depth < 2 then
        local keys = {}
        for k in pairs(v) do
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = tostring(k) .. "=" .. show(v[k], depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function add(fmt, ...)
    local line = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    current.lines[#current.lines + 1] = line
end

-- Runs one named check, keeping its lines and any error.
local function check(name, fn)
    current = { when = now(), lines = {} }
    db.checks[name] = current
    local ok, err = pcall(fn)
    if not ok then
        add("ERROR: %s", tostring(err))
    end
    current.ok = ok
end

-- A value by dotted name, such as "C_QuestLog.GetInfo" or "ObjectiveTrackerFrame.Header".
local function resolve(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then
            return nil
        end
        v = v[part]
    end
    return v
end

local MODULES = {
    "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker", "QuestObjectiveTracker",
    "AdventureObjectiveTracker", "AchievementObjectiveTracker", "MonthlyActivitiesObjectiveTracker",
    "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
}

local function frameState(path)
    local f = resolve(path)
    if not f then
        return path .. ": missing"
    end
    local protected, explicit = f:IsProtected()
    local parent = f:GetParent()
    return string.format("%s: protected %s (explicit %s), shown %s, visible %s, parent %s, size %.0fx%.0f", path, tostring(protected),
        tostring(explicit), tostring(f:IsShown()), tostring(f:IsVisible()), parent and (parent:GetName() or "unnamed") or "nil", f:GetWidth() or 0, f:GetHeight() or 0)
end

local function countBlocks(module)
    local n = 0
    local used = module.usedBlocks
    if type(used) == "table" then
        for _, set in pairs(used) do
            if type(set) == "table" then
                for _ in pairs(set) do
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- Passive checks ---------------------------------------------------------------------------------------------

local function checkEnvironment()
    check("environment", function()
        local version, build, _, interface = GetBuildInfo()
        add("client %s build %s interface %s locale %s", version, build, interface, GetLocale())
        add("probe loads so far: %d", db.loads)
        for i = math.max(1, #db.loadLog - 4), #db.loadLog do
            add("    load %s", show(db.loadLog[i]))
        end
        add("at our ADDON_LOADED: %s", show(db.atLoad))
        for _, name in ipairs({ "Blizzard_ObjectiveTracker", "KaLiQuest", "QuestSectionsForever", "Spoken_Quests", "DialogueUI", "ForeverQuestTint", "Questie", "BugSack", "!BugGrabber", "Zmap", "LoreForever" }) do
            add("addon %s loaded %s", name, tostring(C_AddOns.IsAddOnLoaded(name)))
        end
    end)
end

local function checkProtected()
    check("protected", function()
        add("in combat: %s", tostring(InCombatLockdown()))
        for _, path in ipairs({ "ObjectiveTrackerFrame", "ObjectiveTrackerFrame.Header", "ObjectiveTrackerFrame.NineSlice", "QuestTimerFrame" }) do
            add(frameState(path))
        end
        for _, name in ipairs(MODULES) do
            add(frameState(name))
        end
    end)
end

local function checkSections()
    check("sections", function()
        local container = ObjectiveTrackerFrame
        add("host modules list: %s", container and type(container.modules) == "table" and #container.modules or "?")
        for _, name in ipairs(MODULES) do
            local m = _G[name]
            if m then
                add("%s: blocks %d, hasContents %s, collapsed %s, contentsHeight %s", name, countBlocks(m), tostring(m.hasContents),
                    tostring(m.isCollapsed), tostring(m.contentsHeight))
            end
        end
        local function try(label, fn)
            local ok, a, b = pcall(fn)
            add("%s -> %s %s %s", label, ok and "ok" or "ERROR", show(a), b ~= nil and show(b) or "")
        end
        try("C_Scenario.GetInfo", function()
            return C_Scenario.GetInfo()
        end)
        try("GetTasksTable", function()
            return GetTasksTable()
        end)
        try("C_UIWidgetManager.GetObjectiveTrackerWidgetSetID", function()
            return C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()
        end)
        try("C_ContentTracking.GetCollectableSourceTrackingEnabled", function()
            return C_ContentTracking.GetCollectableSourceTrackingEnabled()
        end)
        try("C_ContentTracking.GetTrackedIDs(achievement)", function()
            return C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
        end)
        try("C_PerksActivities.GetTrackedPerksActivities", function()
            return C_PerksActivities.GetTrackedPerksActivities()
        end)
        try("C_TradeSkillUI.GetRecipesTracked(false)", function()
            return C_TradeSkillUI.GetRecipesTracked(false)
        end)
        try("C_TradeSkillUI.GetRecipesTracked(true)", function()
            return C_TradeSkillUI.GetRecipesTracked(true)
        end)
    end)
end

local LOG_FIELDS = { "questID", "title", "level", "difficultyLevel", "suggestedGroup", "frequency", "isHeader", "isCollapsed",
    "headerSortKey", "isHidden", "isTask", "isBounty", "isAutoComplete", "isOnMap", "hasLocalPOI", "isStory", "campaignID",
    "questClassification", "startEvent", "useMinimalHeader", "sortAsNormalQuest", "overridesSortOrder" }

local function checkLog()
    check("log", function()
        local entries, quests = C_QuestLog.GetNumQuestLogEntries()
        add("GetNumQuestLogEntries -> entries %s, quests %s; watches %s", tostring(entries), tostring(quests), tostring(C_QuestLog.GetNumQuestWatches()))
        for i = 1, entries do
            local info = C_QuestLog.GetInfo(i)
            if info then
                local parts = {}
                for _, key in ipairs(LOG_FIELDS) do
                    if info[key] ~= nil and info[key] ~= false then
                        parts[#parts + 1] = key .. "=" .. show(info[key])
                    end
                end
                add("%d %s", i, table.concat(parts, " "))
            end
        end
    end)
end

local function checkQuests()
    check("quests", function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local onMap = {}
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(list) == "table" then
            for _, q in ipairs(list) do
                onMap[q.questID] = q
            end
        end
        add("map %s (%s), GetQuestsOnMap -> %s", tostring(mapID), tostring(mapID and C_Map.GetMapInfo(mapID) and C_Map.GetMapInfo(mapID).name), ok and #list or ("ERROR " .. tostring(list)))
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                local id = info.questID
                local function safe(fn, ...)
                    local good, a, b, c, d = pcall(fn, ...)
                    if not good then
                        return "ERROR"
                    end
                    return a, b, c, d
                end
                local tag = safe(C_QuestLog.GetQuestTagInfo, id)
                local link, icon, charges, showWhenComplete = safe(GetQuestLogSpecialItemInfo, i)
                local description, objectivesText = safe(GetQuestLogQuestText, i)
                local objectives = safe(C_QuestLog.GetQuestObjectives, id)
                local types = {}
                if type(objectives) == "table" then
                    for _, o in ipairs(objectives) do
                        types[#types + 1] = tostring(o.type) .. "/" .. tostring(o.objectiveType)
                    end
                end
                add("#%d %q", id, info.title or "?")
                add("    tag %s, classification %s, repeatable %s, pushable %s, watch %s, complete %s", show(tag),
                    tostring(safe(C_QuestInfoSystem.GetQuestClassification, id)), tostring(safe(C_QuestLog.IsRepeatableQuest, id)),
                    tostring(safe(C_QuestLog.IsPushableQuest, id)), tostring(safe(C_QuestLog.GetQuestWatchType, id)), tostring(safe(C_QuestLog.IsComplete, id)))
                add("    item %s charges %s whenComplete %s; text %d/%d chars; objectives %s", tostring(link), tostring(charges),
                    tostring(showWhenComplete), type(description) == "string" and #description or -1,
                    type(objectivesText) == "string" and #objectivesText or -1, table.concat(types, ","))
                add("    waypoint %s; distanceSq %s; insideBlob %s; onMap %s; party %s", show(safe(C_QuestLog.GetNextWaypointText, id)),
                    tostring(safe(C_QuestLog.GetDistanceSqToQuest, id)), tostring(safe(C_Minimap.IsInsideQuestBlob, id)),
                    onMap[id] and string.format("%.3f,%.3f", onMap[id].x or 0, onMap[id].y or 0) or "no",
                    tostring(QuestUtils_GetNumPartyMembersOnQuest and safe(QuestUtils_GetNumPartyMembersOnQuest, id)))
            end
        end
    end)
end

local function checkCVars()
    check("cvars", function()
        if C_AddOns.IsAddOnLoaded("KaLiQuest") then
            add("KaLiQuest is loaded and sets autoQuestWatch at PLAYER_LOGIN, so later values are its own. Its saved original: %s",
                tostring(type(KaLiQuestCharDB) == "table" and KaLiQuestCharDB.autoQuestWatchOriginal))
        end
        add("timeline this session:")
        for _, line in ipairs(session.cvarTimeline) do
            add("    %s", line)
        end
        for _, name in ipairs({ "autoQuestWatch", "questPOI", "showQuestObjectivesInLog", "colorblindMode", "scriptErrors", "taintLog" }) do
            local ok, value, default, account, character, locked, secure, readOnly = pcall(C_CVar.GetCVarInfo, name)
            if ok and value ~= nil then
                add("%s = %s (default %s) serverAccount %s serverCharacter %s locked %s secure %s readOnly %s", name, value, tostring(default),
                    tostring(account), tostring(character), tostring(locked), tostring(secure), tostring(readOnly))
            else
                add("%s: %s", name, ok and "unknown" or ("ERROR " .. tostring(value)))
            end
        end
        local value = GetCVar("autoQuestWatch")
        local ok, result = pcall(SetCVar, "autoQuestWatch", value)
        add("SetCVar(autoQuestWatch, same value %s) -> %s %s", tostring(value), ok and "ok" or "ERROR", tostring(result))
    end)
end

local ATLASES = {
    "ui-questtracker-primary-objective-header", "ui-questtracker-secondary-objective-header", "ui-questtrackerbutton-collapse-all",
    "ui-questtrackerbutton-filter", "ui-questtrackerbutton-secondary-expand", "ui-questtracker-tracker-check",
    "covenantsanctum-renown-doublearrow", "gm-icon-visible", "communities-icon-lock", "options_horizontaldivider", "common-icon-undo",
    "questlog-icon-setting", "waypoint-mappin-untracked", "waypoint-mappin-minimap-untracked", "questlog-questtypeicon-dungeon",
    "questlog-questtypeicon-raid", "questlog-questtypeicon-pvp", "questlog-questtypeicon-clockyellow", "questlog-questtypeicon-group",
    "questlog-questtypeicon-daily", "questlog-questtypeicon-weekly", "questlog-questtypeicon-legendary", "questlog-questtypeicon-class",
    "questrepeatableturnin", "socialqueuing-icon-group", "socialqueuing-icon-eye", "questsharing-questlog-button",
    "gearUpdate-arrow-bullet-point", "common-search-magnifyingglass", "minimal-scrollbar-small-thumb-middle",
}

local function checkAtlases()
    check("atlases", function()
        for _, name in ipairs(ATLASES) do
            local info = C_Texture.GetAtlasInfo(name)
            if info then
                add("%s: file %s %sx%s", name, tostring(info.file or info.filename), tostring(info.width), tostring(info.height))
            else
                add("%s: MISSING", name)
            end
        end
    end)
end

local FUNCTIONS = {
    "UseQuestLogSpecialItem", "GetQuestLogSpecialItemInfo", "QuestUtil.ShareQuest", "QuestLogPushQuest", "QuestMapFrame_OpenToQuestDetails",
    "ShowQuestComplete", "ShowQuestOffer", "C_SuperTrack.SetSuperTrackedQuestID", "Settings.OpenToCategory",
    "Settings.RegisterVerticalLayoutCategory", "MenuUtil.CreateContextMenu", "Menu.ModifyMenu", "ScrollUtil.AddTreeDragBehavior",
    "CaseAccentInsensitiveParse", "QuestUtils_GetNumPartyMembersOnQuest", "GetQuestLogQuestText", "C_QuestLog.GetNextWaypointText",
    "C_Minimap.IsInsideQuestBlob", "C_QuestLog.GetDistanceSqToQuest", "LFGListUtil_FindQuestGroup", "QuestUtil.CanCreateQuestGroup",
    "QuestUtil.CanRemoveQuestWatch", "EventRegistry", "MouseIsOver", "RunNextFrame", "EventUtil.ContinueOnAddOnLoaded",
    "AddonCompartmentFrame", "LOCALIZED_CLASS_NAMES_MALE", "ObjectiveTrackerManager", "ObjectiveTrackerManager.AcquireFrame",
    "EditModeManagerFrame", "ObjectiveTrackerQuestPOIBlockTemplate", "C_QuestLog.GetQuestsOnMap", "CreateFramePool",
}

local function checkFunctions()
    check("functions", function()
        for _, path in ipairs(FUNCTIONS) do
            add("%s: %s", path, type(resolve(path)))
        end
        local function hooked(moduleName)
            local m = _G[moduleName]
            if not m then
                return "missing"
            end
            local secure, taint = issecurevariable(m, "AddBlock")
            return string.format("AddBlock differs from the mixin %s, secure %s, taint %s", tostring(m.AddBlock ~= ObjectiveTrackerModuleMixin.AddBlock),
                tostring(secure), tostring(taint))
        end
        add("QuestObjectiveTracker: %s", hooked("QuestObjectiveTracker"))
        add("CampaignQuestObjectiveTracker: %s", hooked("CampaignQuestObjectiveTracker"))
        if CaseAccentInsensitiveParse then
            add("CaseAccentInsensitiveParse(\"Épée ÉLITE à Forgeron\") -> %q", tostring(CaseAccentInsensitiveParse("Épée ÉLITE à Forgeron")))
        end
        local _, classFile = UnitClass("player")
        add("class %s, UnitClass %q, masculine %q", tostring(classFile), tostring((UnitClass("player"))), tostring(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]))
        add("host size %.1fx%.1f, points %d", ObjectiveTrackerFrame:GetWidth(), ObjectiveTrackerFrame:GetHeight(), ObjectiveTrackerFrame:GetNumPoints())
    end)
end

local function runPassive()
    checkEnvironment()
    checkProtected()
    checkSections()
    checkLog()
    checkQuests()
    checkCVars()
    checkAtlases()
    checkFunctions()
    db.passiveAt = now()
end

-- Active tests -----------------------------------------------------------------------------------------------

local parked
local hidden

local function park()
    if parked then
        say("déjà parqué. /kqprobe unpark pour revenir.")
        return
    end
    hidden = hidden or CreateFrame("Frame", nil, nil)
    hidden:Hide()
    parked = { frames = {}, width = ObjectiveTrackerFrame:GetWidth(), updates = 0, hostHidden = 0, ticks = 0 }
    check("park", function()
        local targets = { "ObjectiveTrackerFrame.Header" }
        for _, name in ipairs(MODULES) do
            targets[#targets + 1] = name
        end
        for _, path in ipairs(targets) do
            local f = resolve(path)
            if f then
                local before = f:IsProtected()
                local parent = f:GetParent()
                local ok, err = pcall(f.SetParent, f, hidden)
                parked.frames[#parked.frames + 1] = { path = path, frame = f, parent = parent }
                add("%s: protected before %s, SetParent %s %s", path, tostring(before), ok and "ok" or "ERROR", ok and "" or tostring(err))
            end
        end
        local root = _G.KaLiQuestProbeRoot or CreateFrame("Frame", "KaLiQuestProbeRoot", nil)
        root:SetParent(ObjectiveTrackerFrame)
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
        root:SetSize(260, 40)
        if not root.text then
            root.bg = root:CreateTexture(nil, "BACKGROUND")
            root.bg:SetAllPoints()
            root.bg:SetColorTexture(0, 0, 0, 0.5)
            root.text = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            root.text:SetPoint("CENTER")
            root.text:SetText("KaLi Quest probe : sections parquées")
        end
        root:Show()
        parked.root = root
        local ok, err = pcall(ObjectiveTrackerFrame.SetWidth, ObjectiveTrackerFrame, parked.width + 12)
        add("host SetWidth(%d) %s %s", parked.width + 12, ok and "ok" or "ERROR", ok and "" or tostring(err))
        if not session.updateHooked then
            session.updateHooked = true
            hooksecurefunc(ObjectiveTrackerFrame, "Update", function()
                if parked then
                    parked.updates = parked.updates + 1
                end
            end)
        end
        add("host protected %s, shown %s", tostring(ObjectiveTrackerFrame:IsProtected()), tostring(ObjectiveTrackerFrame:IsShown()))
    end)
    -- Watch for 60 seconds whether anything brings the sections back or hides the host.
    parked.ticker = C_Timer.NewTicker(1, function()
        if not parked then
            return
        end
        parked.ticks = parked.ticks + 1
        if not ObjectiveTrackerFrame:IsShown() then
            parked.hostHidden = parked.hostHidden + 1
        end
        local lines = db.checks.park.lines
        for _, p in ipairs(parked.frames) do
            if p.frame:GetParent() ~= hidden and not p.reported then
                p.reported = true
                lines[#lines + 1] = string.format("after %ds: %s left the hidden frame (parent %s)", parked.ticks, p.path, tostring(p.frame:GetParent() and p.frame:GetParent():GetName()))
            end
        end
        if parked.ticks == 60 then
            lines[#lines + 1] = string.format("after 60s: host Update ran %d times, host hidden on %d ticks, width %.1f, combat seen %s", parked.updates,
                parked.hostHidden, ObjectiveTrackerFrame:GetWidth(), tostring(session.combatSeen))
            say("park : 60 s observées, résultat enregistré.")
        end
    end, 60)
    say("sections parquées. Jouez normalement (suivre, combattre, Edit Mode), puis /kqprobe unpark. /reload remet tout aussi.")
end

local function unpark()
    if not parked then
        say("rien de parqué.")
        return
    end
    local lines = db.checks.park.lines
    for _, p in ipairs(parked.frames) do
        local ok, err = pcall(p.frame.SetParent, p.frame, p.parent)
        if not ok then
            lines[#lines + 1] = "unpark " .. p.path .. ": ERROR " .. tostring(err)
        end
    end
    pcall(ObjectiveTrackerFrame.SetWidth, ObjectiveTrackerFrame, parked.width)
    parked.root:Hide()
    if parked.ticker then
        parked.ticker:Cancel()
    end
    lines[#lines + 1] = string.format("unparked after %ds: host Update ran %d times, host hidden on %d ticks", parked.ticks, parked.updates, parked.hostHidden)
    parked = nil
    say("tout est revenu.")
end

local function firstQuestID()
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
            return info.questID, info.title
        end
    end
end

local function testRow(arg)
    local questID, title = tonumber(arg), nil
    if questID then
        title = C_QuestLog.GetTitleForQuestID(questID)
    else
        questID, title = firstQuestID()
    end
    if not questID then
        say("aucune quête dans le journal.")
        return
    end
    check("row", function()
        local row = _G.KaLiQuestProbeRow or CreateFrame("Frame", "KaLiQuestProbeRow", nil)
        row:SetParent(UIParent)
        row:ClearAllPoints()
        row:SetPoint("CENTER", 0, 120)
        row:SetSize(260, 40)
        if not row.HeaderText then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0, 0, 0, 0.6)
            row.HeaderText = row:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerLineFont")
            row.HeaderText:SetPoint("LEFT", 8, 0)
        end
        row.id = questID
        row.HeaderText:SetText(title or ("#" .. questID))
        row:Show()
        local before = select("#", row:GetChildren())
        -- Blizzard's AddBlock only writes to self, and CanFitBlock = false makes it do nothing else.
        local standIn = setmetatable({ CanFitBlock = function()
            return false
        end }, { __index = QuestObjectiveTracker })
        local ok, err = pcall(QuestObjectiveTracker.AddBlock, standIn, row)
        add("quest #%d, AddBlock on a stand-in: %s %s", questID, ok and "ok" or "ERROR", ok and "" or tostring(err))
        add("stand-in wrote hasTriedBlocks %s; the real section's value %s", tostring(rawget(standIn, "hasTriedBlocks")), tostring(QuestObjectiveTracker.hasTriedBlocks))
        C_Timer.After(0.5, function()
            local lines = db.checks.row.lines
            local children = { row:GetChildren() }
            lines[#lines + 1] = string.format("children before %d, after 0.5s %d", before, #children)
            for _, child in ipairs(children) do
                lines[#lines + 1] = string.format("    %s %s shown %s size %.0fx%.0f", child:GetObjectType(), tostring(child:GetName()), tostring(child:IsShown()), child:GetWidth(), child:GetHeight())
            end
        end)
    end)
    say("ligne de test au centre pour #" .. questID .. ". Si un bouton ▶ de Spoken apparaît, cliquez-le. /kqprobe hide pour l'enlever.")
end

local function testItem()
    local logIndex, questID
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and GetQuestLogSpecialItemInfo(i) then
            logIndex, questID = i, info.questID
            break
        end
    end
    if not logIndex then
        say("aucune quête avec un objet à utiliser dans le journal.")
        return
    end
    check("item", function()
        local link, icon = GetQuestLogSpecialItemInfo(logIndex)
        add("quest #%d, item %s", questID, tostring(link))
        local b = _G.KaLiQuestProbeItem or CreateFrame("Button", "KaLiQuestProbeItem", nil)
        b:SetParent(UIParent)
        b:ClearAllPoints()
        b:SetPoint("CENTER", 0, 40)
        b:SetSize(36, 36)
        b:SetNormalTexture(icon)
        b:RegisterForClicks("AnyUp")
        b:SetScript("OnClick", function()
            local lines = db.checks.item.lines
            local combat = InCombatLockdown()
            local blockedBefore = #session.blocked
            local ok, err = pcall(UseQuestLogSpecialItem, logIndex)
            lines[#lines + 1] = string.format("%s click, combat %s: UseQuestLogSpecialItem %s %s", now(), tostring(combat), ok and "ok" or "ERROR", ok and "" or tostring(err))
            C_Timer.After(1, function()
                for i = blockedBefore + 1, #session.blocked do
                    lines[#lines + 1] = "    blocked: " .. session.blocked[i]
                end
                if #session.blocked == blockedBefore then
                    lines[#lines + 1] = "    nothing blocked"
                end
            end)
        end)
        b:Show()
    end)
    say("bouton d'objet simple au centre. Cliquez-le hors combat, puis en combat. /kqprobe hide pour l'enlever.")
end

local function hideTests()
    for _, name in ipairs({ "KaLiQuestProbeRow", "KaLiQuestProbeItem" }) do
        if _G[name] then
            _G[name]:Hide()
        end
    end
end

local function eventsText(list)
    return #list .. " event(s)" .. (#list > 0 and (": " .. table.concat(list, "; ")) or "")
end

-- Risk 4: several watch changes in one frame, and AddQuestWatch near the 25. Uses untracked quests only and
-- untracks them again a second later.
local function testWatch()
    local picked = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and not info.isTask and info.questID and C_QuestLog.GetQuestWatchType(info.questID) == nil then
            picked[#picked + 1] = info.questID
            if #picked == 3 then
                break
            end
        end
    end
    if #picked == 0 then
        say("aucune quête non suivie dans le journal.")
        return
    end
    check("watch", function()
        session.watchEvents = {}
        add("before: %d tracked; adding %s in one frame", C_QuestLog.GetNumQuestWatches(), table.concat(picked, ", "))
        for _, id in ipairs(picked) do
            local ok, result = pcall(C_QuestLog.AddQuestWatch, id)
            add("AddQuestWatch(%d) -> %s %s", id, ok and "ok" or "ERROR", tostring(result))
        end
        add("after: %d tracked", C_QuestLog.GetNumQuestWatches())
    end)
    C_Timer.After(1, function()
        local lines = db.checks.watch.lines
        lines[#lines + 1] = "within 1s of adding: " .. eventsText(session.watchEvents)
        session.watchEvents = {}
        for _, id in ipairs(picked) do
            local ok, result = pcall(C_QuestLog.RemoveQuestWatch, id)
            lines[#lines + 1] = string.format("RemoveQuestWatch(%d) -> %s %s", id, ok and "ok" or "ERROR", tostring(result))
        end
        C_Timer.After(1, function()
            lines[#lines + 1] = "within 1s of removing: " .. eventsText(session.watchEvents)
            lines[#lines + 1] = string.format("end: %d tracked", C_QuestLog.GetNumQuestWatches())
            session.watchEvents = nil
            say("watch : résultat enregistré.")
        end)
    end)
    say("suivi de " .. #picked .. " quêtes d'un coup, retiré dans une seconde.")
end

local function countLog()
    local entries, quests = C_QuestLog.GetNumQuestLogEntries()
    local rows = 0
    for i = 1, entries or 0 do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            rows = rows + 1
        end
    end
    return entries or 0, quests or 0, rows
end

local function headerCollapsed(index)
    local info = C_QuestLog.GetInfo(index)
    return tostring(info and info.isCollapsed)
end

-- Risk 8: whether quests under a collapsed header still come out of C_QuestLog.GetInfo. Expands it again after.
local function testCollapse()
    local headerIndex, title
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info, nextInfo = C_QuestLog.GetInfo(i), C_QuestLog.GetInfo(i + 1)
        if info and info.isHeader and not info.isCollapsed and nextInfo and not nextInfo.isHeader then
            headerIndex, title = i, info.title
            break
        end
    end
    if not headerIndex then
        say("aucun en-tête ouvert avec des quêtes.")
        return
    end
    check("collapse", function()
        add("header %d %q", headerIndex, tostring(title))
        add("before: header collapsed %s, entries %d, quests %d, quest rows %d", headerCollapsed(headerIndex), countLog())
        CollapseQuestHeader(headerIndex)
        add("right after CollapseQuestHeader: header collapsed %s, entries %d, quests %d, quest rows %d", headerCollapsed(headerIndex), countLog())
    end)
    C_Timer.After(0.5, function()
        local lines = db.checks.collapse.lines
        lines[#lines + 1] = string.format("after 0.5s: header collapsed %s, entries %d, quests %d, quest rows %d", headerCollapsed(headerIndex), countLog())
        ExpandQuestHeader(headerIndex)
        C_Timer.After(0.5, function()
            lines[#lines + 1] = string.format("expanded again: header collapsed %s, entries %d, quests %d, quest rows %d", headerCollapsed(headerIndex), countLog())
            say("collapse : résultat enregistré.")
        end)
    end)
end

local ORDER = { "environment", "protected", "sections", "log", "quests", "cvars", "atlases", "functions", "park", "row", "item", "watch",
    "collapse", "menus", "events" }

local function reportText()
    local out = { "KaLi Quest probe, passive checks at " .. tostring(db.passiveAt) }
    db.checks.events = { when = now(), lines = {} }
    local counts = {}
    for event, n in pairs(db.eventCounts) do
        counts[#counts + 1] = event .. " " .. n
    end
    table.sort(counts)
    db.checks.events.lines[1] = "counts this session: " .. table.concat(counts, ", ")
    for i = math.max(1, #db.events - 80), #db.events do
        db.checks.events.lines[#db.checks.events.lines + 1] = db.events[i]
    end
    for _, name in ipairs(ORDER) do
        local c = db.checks[name]
        if c then
            out[#out + 1] = string.format("\n== %s (%s)%s ==", name, c.when, c.ok == false and " FAILED" or "")
            for _, line in ipairs(c.lines) do
                out[#out + 1] = line
            end
        end
    end
    return table.concat(out, "\n")
end

local window
local function showReport()
    if not window then
        window = CreateFrame("Frame", "KaLiQuestProbeWindow", nil, "BackdropTemplate")
        window:SetParent(UIParent)
        window:SetFrameStrata("DIALOG")
        window:SetSize(760, 540)
        window:SetPoint("CENTER")
        window:SetBackdrop(BACKDROP_DARK_DIALOG_32_32)
        window:EnableMouse(true)
        tinsert(UISpecialFrames, "KaLiQuestProbeWindow")
        local close = CreateFrame("Button", nil, nil, "UIPanelCloseButton")
        close:SetParent(window)
        close:SetPoint("TOPRIGHT", -6, -6)
        local scroll = CreateFrame("ScrollFrame", nil, nil, "UIPanelScrollFrameTemplate")
        scroll:SetParent(window)
        scroll:SetPoint("TOPLEFT", 18, -30)
        scroll:SetPoint("BOTTOMRIGHT", -36, 18)
        local edit = CreateFrame("EditBox", nil, nil)
        edit:SetParent(scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(690)
        edit:SetScript("OnEscapePressed", function()
            window:Hide()
        end)
        scroll:SetScrollChild(edit)
        window.edit = edit
    end
    window.edit:SetText(reportText())
    window:Show()
end

-- Recording ---------------------------------------------------------------------------------------------------

local RECORDED = {
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE", "QUEST_DETAIL",
    "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_AUTOCOMPLETE", "SUPER_TRACKING_CHANGED", "PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "UNIT_QUEST_LOG_CHANGED", "QUEST_POI_UPDATE", "PLAYER_LOGIN", "VARIABLES_LOADED",
}
local COUNTED_ONLY = { QUEST_LOG_UPDATE = true }
local NPC_EVENTS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true, QUEST_ACCEPTED = true, QUEST_TURNED_IN = true }

local function guidOf(unit)
    local guid = UnitGUID(unit)
    if guid ~= nil and issecretvalue and issecretvalue(guid) then
        return "(secret)"
    end
    return tostring(guid)
end

local function record(event, ...)
    db.eventCounts[event] = (db.eventCounts[event] or 0) + 1
    if COUNTED_ONLY[event] then
        return
    end
    -- Settings sliders fire hundreds of these; only auto-tracking matters here.
    if event == "CVAR_UPDATE" and not (type(...) == "string" and (...):lower() == "autoquestwatch") then
        return
    end
    local args = {}
    for i = 1, select("#", ...) do
        args[#args + 1] = show((select(i, ...)))
    end
    local line = string.format("%s t=%.3f %s %s", date("%H:%M:%S"), GetTime(), event, table.concat(args, ", "))
    if NPC_EVENTS[event] then
        line = line .. string.format("  questnpc %s, npc %s, GetQuestID %s", guidOf("questnpc"), guidOf("npc"), tostring(GetQuestID and GetQuestID()))
    end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        session.blocked[#session.blocked + 1] = line
    end
    if event == "PLAYER_REGEN_DISABLED" then
        session.combatSeen = true
    end
    if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
        noteCVar(event)
    elseif event == "CVAR_UPDATE" and type(...) == "string" and (...):lower() == "autoquestwatch" then
        noteCVar("CVAR_UPDATE " .. table.concat(args, ", "))
    elseif event == "QUEST_WATCH_LIST_CHANGED" and session.watchEvents then
        session.watchEvents[#session.watchEvents + 1] = table.concat(args, ", ")
    end
    db.events[#db.events + 1] = line
    if #db.events > 600 then
        table.remove(db.events, 1)
    end
end

local function hookMenus()
    if not (Menu and Menu.ModifyMenu) then
        return
    end
    for _, tag in ipairs({ "MENU_QUEST_MAP_LOG_TITLE", "MENU_QUEST_OBJECTIVE_TRACKER" }) do
        Menu.ModifyMenu(tag, function(owner, _, contextData)
            local c = db.checks.menus or { when = now(), lines = {} }
            db.checks.menus = c
            local keys = {}
            for k in pairs(type(contextData) == "table" and contextData or {}) do
                keys[#keys + 1] = tostring(k)
            end
            c.lines[#c.lines + 1] = string.format("%s %s: owner %s %s, owner.questID %s, contextData keys {%s}", now(), tag,
                owner and owner.GetObjectType and owner:GetObjectType() or type(owner), owner and owner.GetName and tostring((owner:GetName())) or "",
                tostring(owner and owner.questID), table.concat(keys, ", "))
            while #c.lines > 10 do
                table.remove(c.lines, 1)
            end
        end)
    end
end

local frame = CreateFrame("Frame", nil, nil)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then
            return
        end
        KaLiQuestProbeDB = type(KaLiQuestProbeDB) == "table" and KaLiQuestProbeDB or {}
        db = KaLiQuestProbeDB
        db.checks = db.checks or {}
        db.loads = (db.loads or 0) + 1
        db.loadLog = db.loadLog or {}
        db.loadLog[#db.loadLog + 1] = { n = db.loads, at = now(), build = select(2, GetBuildInfo()) }
        while #db.loadLog > 20 do
            table.remove(db.loadLog, 1)
        end
        db.events = {}
        db.eventCounts = {}
        db.atLoad = {
            trackerLoaded = C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker"),
            manager = ObjectiveTrackerManager ~= nil,
            host = ObjectiveTrackerFrame ~= nil,
        }
        for _, e in ipairs(RECORDED) do
            frame:RegisterEvent(e)
        end
        frame:RegisterEvent("QUEST_LOG_UPDATE")
        hookMenus()
        noteCVar("probe's ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not session.ran then
            session.ran = true
            noteCVar("PLAYER_ENTERING_WORLD")
            -- After ObjectiveTrackerManager:Init, which waits for this event and VARIABLES_LOADED.
            C_Timer.After(3, function()
                runPassive()
                say("vérifications enregistrées. /kqprobe show pour le rapport, /kqprobe pour les tests actifs.")
            end)
        end
    else
        record(event, ...)
    end
end)

SLASH_KQPROBE1 = "/kqprobe"
SlashCmdList.KQPROBE = function(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "run" then
        runPassive()
        say("vérifications refaites.")
    elseif cmd == "show" then
        showReport()
    elseif cmd == "park" then
        park()
    elseif cmd == "unpark" then
        unpark()
    elseif cmd == "row" then
        testRow(rest)
    elseif cmd == "item" then
        testItem()
    elseif cmd == "watch" then
        testWatch()
    elseif cmd == "collapse" then
        testCollapse()
    elseif cmd == "hide" then
        hideTests()
    elseif cmd == "reset" then
        wipe(db.checks)
        say("rapport effacé.")
    else
        say("/kqprobe show | run | park | unpark | row [quête] | item | watch | collapse | hide | reset")
    end
end
