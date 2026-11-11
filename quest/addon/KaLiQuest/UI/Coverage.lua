-- Blizzard's sections the addon doesn't draw. They keep running out of sight, so after each of their own layouts
-- this reads whether they found something to show. While one has, the addon steps aside for Blizzard's tracker and
-- comes back once it's empty, Ikar's ruling on 2026-11-07. Each one seen is kept, to learn what fills on Forever.
local _, ns = ...
local L = ns.L
local Shared = ns.Tracker.Shared

local Coverage = {}
ns.Coverage = Coverage

Coverage.SECTIONS = {
    { frame = "ScenarioObjectiveTracker", name = "TRACKER_HEADER_SCENARIO", fallback = "Scénario" },
    { frame = "UIWidgetObjectiveTracker", label = "ZONE_WIDGETS" },
    { frame = "BonusObjectiveTracker", name = "TRACKER_HEADER_BONUS_OBJECTIVES", fallback = "Objectifs bonus" },
    { frame = "WorldQuestObjectiveTracker", name = "TRACKER_HEADER_WORLD_QUESTS", fallback = "Expéditions" },
    { frame = "AdventureObjectiveTracker", name = "ADVENTURE_TRACKING_MODULE_HEADER_TEXT", fallback = "Collections" },
    { frame = "MonthlyActivitiesObjectiveTracker", name = "TRACKER_HEADER_MONTHLY_ACTIVITIES", fallback = "Journal de voyage" },
    { frame = "InitiativeTasksObjectiveTracker", name = "TRACKER_HEADER_INITIATIVE_TASKS", fallback = "Initiatives" },
}
-- The ones the addon draws itself, for the debug panel.
Coverage.DRAWN = {
    { frame = "QuestObjectiveTracker", name = "TRACKER_HEADER_QUESTS", fallback = "Quêtes" },
    { frame = "CampaignQuestObjectiveTracker", name = "TRACKER_HEADER_CAMPAIGN_QUESTS", fallback = "Campagne" },
    { frame = "AchievementObjectiveTracker", name = "TRACKER_HEADER_ACHIEVEMENTS", fallback = "Hauts faits" },
    { frame = "ProfessionsRecipeTracker", name = "PROFESSIONS_TRACKER_HEADER_PROFESSION", fallback = "Métier" },
}

local call = ns.Call

function Coverage.Label(s)
    if s.module then
        return type(s.module.headerText) == "string" and s.module.headerText or s.frame
    end
    return s.label and L[s.label] or ns.G(s.name, s.fallback)
end

-- Blizzard's sections above, then any other addon's own section in Blizzard's tracker.
function Coverage.List()
    local list, known = {}, {}
    for _, group in ipairs({ Coverage.SECTIONS, Coverage.DRAWN }) do
        for _, s in ipairs(group) do
            known[s.frame] = true
        end
    end
    for _, s in ipairs(Coverage.SECTIONS) do
        list[#list + 1] = s
    end
    local host = ObjectiveTrackerFrame
    for _, m in ipairs(host and type(host.modules) == "table" and host.modules or {}) do
        local name = m.GetName and m:GetName()
        if not (name and known[name]) then
            list[#list + 1] = { frame = name or tostring(m), module = m }
        end
    end
    return list
end

local function unfinished(tracked, info)
    for _, id in ipairs(type(tracked) == "table" and tracked.trackedIDs or {}) do
        local i = call(info, id)
        if i and not i.completed then
            return true
        end
    end
    return false
end

-- After Blizzard's quests a section can be left no room, and then never looks, so these also ask the game what the
-- section itself would.
local ASK = {
    WorldQuestObjectiveTracker = function()
        if (call(C_QuestLog.GetNumWorldQuestWatches) or 0) > 0 then
            return true
        end
        for _, id in ipairs(call(GetTasksTable) or {}) do
            if call(C_QuestLog.IsWorldQuest, id) then
                return true
            end
        end
        return false
    end,
    AdventureObjectiveTracker = function()
        if not (C_ContentTracking and call(C_ContentTracking.GetCollectableSourceTrackingEnabled)) then
            return false
        end
        for _, kind in ipairs(call(C_ContentTracking.GetCollectableSourceTypes) or {}) do
            for _, id in ipairs(call(C_ContentTracking.GetTrackedIDs, kind) or {}) do
                if call(C_ContentTracking.GetCurrentTrackingTarget, kind, id) then
                    return true
                end
            end
        end
        return false
    end,
    MonthlyActivitiesObjectiveTracker = function()
        return C_PerksActivities ~= nil
            and unfinished(call(C_PerksActivities.GetTrackedPerksActivities), C_PerksActivities.GetPerksActivityInfo)
    end,
    InitiativeTasksObjectiveTracker = function()
        return C_NeighborhoodInitiative ~= nil
            and unfinished(call(C_NeighborhoodInitiative.GetTrackedInitiativeTasks), C_NeighborhoodInitiative.GetInitiativeTaskInfo)
    end,
}

local filled = {} -- section frame name -> true
local ignored = {} -- filled sections the player kept KaLi Quest over, until they empty
local aside -- nil, "section" while one fills, or "manual"
local shownHere = "" -- the sections the alert line names, to redraw only when that changes
local changes = {}
local SIMULATED = "ScenarioObjectiveTracker"
local simulating = false -- /kq alert: a scenario that isn't there, to try all this in game
local tests = {} -- section frame name -> true while its fill is /kq alert's

local function note(text)
    table.insert(changes, 1, date("%H:%M:%S") .. "  " .. text)
    changes[11] = nil
    ns.Debug.Log("coverage", "%s", text)
end

-- Account-wide, so every character's play adds to what's known to fill on Forever.
local function remember(s)
    local d = KaLiQuestDevDB
    if type(d) ~= "table" then
        return
    end
    d.sectionsSeen = type(d.sectionsSeen) == "table" and d.sectionsSeen or {}
    local seen = d.sectionsSeen[s.frame] or { count = 0, first = date("%Y-%m-%d %H:%M") }
    seen.count = seen.count + 1
    seen.last = date("%Y-%m-%d %H:%M")
    seen.zone = GetRealZoneText and GetRealZoneText() or nil
    d.sectionsSeen[s.frame] = seen
end

local function alert(text)
    if UIErrorsFrame and UIErrorsFrame.AddExternalWarningMessage then
        UIErrorsFrame:AddExternalWarningMessage(ns.TITLE .. " : " .. text)
    end
    ns.Say(text)
end

local function names(test)
    local out = {}
    for _, s in ipairs(Coverage.List()) do
        if test(s.frame) then
            out[#out + 1] = Coverage.Label(s)
        end
    end
    return out
end

local function blocking()
    return names(function(frame)
        return filled[frame] and not ignored[frame]
    end)
end

function Coverage.IsFilled(s)
    if simulating and s.frame == SIMULATED then
        return true
    end
    local f = s.module or _G[s.frame]
    local ask = ASK[s.frame]
    return (f ~= nil and (f.hasContents == true or f.hasTriedBlocks == true)) or (ask ~= nil and ask() == true)
end

function Coverage.Check()
    local now = {}
    for _, s in ipairs(Coverage.List()) do
        if Coverage.IsFilled(s) then
            now[s.frame] = true
            if not filled[s.frame] then
                -- A test isn't something seen on Forever, and the log says which fills were tests.
                tests[s.frame] = simulating and s.frame == SIMULATED or nil
                if not tests[s.frame] then
                    remember(s)
                end
                note(string.format(tests[s.frame] and L.SECTION_FILLED_TEST or L.SECTION_FILLED, Coverage.Label(s)))
            end
        elseif filled[s.frame] then
            note(string.format(tests[s.frame] and L.SECTION_EMPTIED_TEST or L.SECTION_EMPTIED, Coverage.Label(s)))
            tests[s.frame] = nil
        end
    end
    filled = now
    for frame in pairs(ignored) do
        if not filled[frame] then
            ignored[frame] = nil
        end
    end
    local here = table.concat(names(function(frame)
        return filled[frame] and ignored[frame]
    end), ", ")
    if here ~= shownHere then
        shownHere = here
        ns.RequestRefresh()
    end
    -- Tracker frames don't change hands in a fight: PLAYER_REGEN_ENABLED looks again.
    if InCombatLockdown() or not ns.db then
        return
    end
    local waiting = blocking()
    if #waiting > 0 and ns.Tracker.IsActive() then
        aside = "section"
        ns.Tracker.SetEnabled(false)
        alert(string.format(L.STEPPED_ASIDE, table.concat(waiting, ", ")))
    elseif #waiting == 0 and aside == "section" then
        aside = nil
        if ns.db.options.tracker ~= false then
            ns.Tracker.SetEnabled(true)
            ns.Say(L.BACK)
        end
    end
end

local function later()
    ns.Later("coverage", Coverage.Check)
end

function Coverage.Start()
    for _, s in ipairs(Coverage.SECTIONS) do
        local f = _G[s.frame]
        if f and type(f.Update) == "function" then
            hooksecurefunc(f, "Update", later)
        end
    end
    ns.On("PLAYER_REGEN_ENABLED", later)
    later()
end

-- /kq tracker on, the options page and the debug panel: KaLi Quest's tracker, over any section filled right now.
function Coverage.Resume()
    for frame in pairs(filled) do
        ignored[frame] = true
    end
    aside = nil
    ns.Tracker.SetEnabled(true)
    later()
end

-- The alert line and the debug panel: Blizzard's tracker, until what fills now has emptied, or until resumed.
function Coverage.StepAside()
    if InCombatLockdown() then
        Shared.refuse("combat")
        return
    end
    wipe(ignored)
    aside = next(filled) and "section" or "manual"
    ns.Tracker.SetEnabled(false)
end

function Coverage.Aside()
    return aside, table.concat(blocking(), ", ")
end

function Coverage.Simulate(on)
    simulating = on == true
    ns.Say(simulating and L.ALERT_TEST_ON or L.ALERT_TEST_OFF)
    later()
end

function Coverage.Simulating()
    return simulating
end

function Coverage.Changes()
    return changes
end

function Coverage.State(frame)
    if not filled[frame] then
        return "empty"
    end
    return ignored[frame] and "kept" or "filled"
end

-- A line on top of the tracker while a section filled is only in Blizzard's, because the player kept this one.
local line
function Coverage.Build(fixed)
    local s = Shared
    line = s.newFrame("Button", fixed)
    line.Text = line:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    line.Text:SetPoint("TOPLEFT")
    line.Text:SetJustifyH("LEFT")
    line.Text:SetTextColor(1, 0.5, 0.25)
    line:SetScript("OnClick", s.guarded(Coverage.StepAside))
    line:SetScript("OnEnter", s.guarded(function(self)
        s.wake()
        s.simpleTip(self, L.HIDDEN_HERE_TIP)
    end))
    line:SetScript("OnLeave", s.guarded(s.hideTip))
    line:Hide()
end

function Coverage.Layout(fixed, width)
    if shownHere == "" then
        line:Hide()
        return 0
    end
    line.Text:SetWidth(width - 14)
    line.Text:SetText(string.format(L.HIDDEN_HERE, shownHere))
    local height = line.Text:GetStringHeight()
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", fixed, "TOPLEFT", 7, 0)
    line:SetSize(width - 14, height)
    line:EnableMouse(not Shared.EditMode())
    line:Show()
    return height + 6
end

function Coverage.Line()
    return line
end
