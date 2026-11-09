-- The player's groups and where quests go. Pure logic over the saved table and a "world" that stands for the
-- game, so the same code runs in game and in tests. See docs/organiser-design.md, "Tracked means in a group".
--
-- world:IsWatched(id), world:WatchedList() -> ids, world:AddWatch(id) -> bool, world:RemoveWatch(id) -> bool,
-- world:CanRemoveWatch(), world:InCombat(), world:HasQuest(id)
local _, ns = ...

local Model = {}
Model.__index = Model
ns.Model = Model

-- A quest accepted from the same NPC this soon after a placed quest's turn-in takes its slot.
Model.FOLLOW_UP_SECONDS = 120
-- Letters in a group's name, as the rename box allows.
Model.NAME_MAX = 40
-- Quests the game tracks at most, as the off-list marker's text says. The model only reads AddWatch's refusal.
Model.WATCH_LIMIT = 25

function Model.New(db, world, firstGroupName)
    return setmetatable({
        db = db,
        world = world,
        firstGroupName = firstGroupName or "Quêtes",
        watched = nil, -- the game's list as last followed; nil until login reconciliation
        turnIns = {}, -- recent turn-ins of placed quests, for the follow-up rule. Not saved
        deleted = nil, -- the last deleted group, for undo. Not saved
    }, Model)
end

local function log(fmt, ...)
    if ns.Debug then
        ns.Debug.Log("model", fmt, ...)
    end
end

function Model:GroupByID(id)
    for index, g in ipairs(self.db.groups) do
        if g.id == id then
            return g, index
        end
    end
end

function Model:GroupOf(questID)
    for _, g in ipairs(self.db.groups) do
        for index, q in ipairs(g.quests) do
            if q == questID then
                return g, index
            end
        end
    end
end

local function takeOut(db, questID)
    for _, g in ipairs(db.groups) do
        for i = #g.quests, 1, -1 do
            if g.quests[i] == questID then
                table.remove(g.quests, i)
            end
        end
    end
end

-- Explicit whitespace: %s follows the C library's locale, where byte 160 can count and cut a UTF-8 "à" in half.
local function trimmed(name)
    return type(name) == "string" and name:match("^[ \t\r\n]*(.-)[ \t\r\n]*$") or ""
end

-- Trimmed, and cut after NAME_MAX letters, counted as UTF-8 characters.
local function groupName(name)
    name = trimmed(name)
    local letters = 0
    for at in name:gmatch("()[^\128-\191]") do
        letters = letters + 1
        if letters > Model.NAME_MAX then
            return trimmed(name:sub(1, at - 1))
        end
    end
    return name
end

-- Whether taking these quests out would need an untrack the game refuses, as in the New Player Experience.
function Model:UntrackRefused(quests)
    if self.world:CanRemoveWatch() then
        return false
    end
    for _, q in ipairs(quests) do
        if self.world:HasQuest(q) and self.world:IsWatched(q) then
            return true
        end
    end
    return false
end

-- A new group goes last, open.
function Model:CreateGroup(name)
    if self.world:InCombat() then
        return nil, "combat"
    end
    name = groupName(name)
    if name == "" then
        return nil, "empty"
    end
    local db = self.db
    local g = { id = db.nextGroupID, name = name, quests = {} }
    db.nextGroupID = db.nextGroupID + 1
    db.groups[#db.groups + 1] = g
    db.open.categories.mine = true
    db.open.groups[g.id] = true
    log("created group %d %q", g.id, name)
    return g
end

-- An empty name changes nothing.
function Model:RenameGroup(id, name)
    local g = self:GroupByID(id)
    if not g then
        return nil, "missing"
    end
    name = groupName(name)
    if name == "" then
        return nil, "empty"
    end
    g.name = name
    return g
end

-- Its quests return to their automatic place, untracked. Refused in combat, Ikar's ruling.
function Model:DeleteGroup(id)
    if self.world:InCombat() then
        return nil, "combat"
    end
    local g, index = self:GroupByID(id)
    if not g then
        return nil, "missing"
    end
    if self:UntrackRefused(g.quests) then
        return nil, "npe"
    end
    table.remove(self.db.groups, index)
    self.deleted = { group = g, index = index, open = self.db.open.groups[id] == true }
    self.db.open.groups[id] = nil
    for _, q in ipairs(g.quests) do
        if self.world:HasQuest(q) then
            self.world:RemoveWatch(q)
        end
    end
    log("deleted group %d with %d quests", id, #g.quests)
    return g
end

-- Brings the last deleted group back in its place, with its quests tracked again, except any that joined
-- another group since.
function Model:UndoDelete()
    local d = self.deleted
    if not d then
        return nil, "nothing"
    end
    if self.world:InCombat() then
        return nil, "combat"
    end
    self.deleted = nil
    local quests = {}
    for _, q in ipairs(d.group.quests) do
        if not self:GroupOf(q) then
            quests[#quests + 1] = q
        end
    end
    local g = { id = d.group.id, name = d.group.name, quests = quests }
    table.insert(self.db.groups, math.min(d.index, #self.db.groups + 1), g)
    self.db.open.groups[g.id] = d.open or nil
    for _, q in ipairs(quests) do
        if self.world:HasQuest(q) then
            self.world:AddWatch(q)
        end
    end
    log("undid deletion of group %d", g.id)
    return g
end

function Model:ReorderGroup(id, newIndex)
    if self.world:InCombat() then
        return nil, "combat"
    end
    local g, index = self:GroupByID(id)
    if not g then
        return nil, "missing"
    end
    table.remove(self.db.groups, index)
    newIndex = math.max(1, math.min(newIndex, #self.db.groups + 1))
    table.insert(self.db.groups, newIndex, g)
    return g
end

-- Into a group, at an index or at its end, and tracked. groupID nil takes it out and stops tracking it.
-- Past the game's 25 the quest stays in its group anyway, off the game's list.
function Model:MoveQuest(questID, groupID, index)
    if self.world:InCombat() then
        return nil, "combat"
    end
    local target
    if groupID then
        target = self:GroupByID(groupID)
        if not target then
            return nil, "missing"
        end
    elseif self:UntrackRefused({ questID }) then
        return nil, "npe"
    end
    takeOut(self.db, questID)
    local inLog = self.world:HasQuest(questID)
    if target then
        if index and index >= 1 and index <= #target.quests then
            table.insert(target.quests, index, questID)
        else
            target.quests[#target.quests + 1] = questID
        end
        self.db.open.categories.mine = true
        if inLog then
            self.world:AddWatch(questID)
        end
    elseif inLog then
        self.world:RemoveWatch(questID)
    end
    log("moved %d to %s", questID, tostring(groupID))
    return true
end

-- Several quests at once, in the order given, so they land side by side. index counts only the target's quests that
-- aren't moving, so dropping them on one of their own rows gathers them there.
function Model:MoveQuests(ids, groupID, index)
    if self.world:InCombat() then
        return nil, "combat"
    end
    if groupID then
        if not self:GroupByID(groupID) then
            return nil, "missing"
        end
    elseif self:UntrackRefused(ids) then
        return nil, "npe"
    end
    for _, id in ipairs(ids) do
        takeOut(self.db, id)
    end
    for i, id in ipairs(ids) do
        self:MoveQuest(id, groupID, index and index + i - 1)
    end
    return true
end

-- A quest the game started tracking joins the end of the top group. With no groups, it starts one, open.
function Model:PlaceTracked(questID)
    local db = self.db
    local g = db.groups[1]
    local created = false
    if not g then
        g = { id = db.nextGroupID, name = self.firstGroupName, quests = {} }
        db.nextGroupID = db.nextGroupID + 1
        db.groups[1] = g
        db.open.categories.mine = true
        db.open.groups[g.id] = true
        created = true
    end
    g.quests[#g.quests + 1] = questID
    log("placed tracked %d in group %d%s", questID, g.id, created and " (new)" or "")
    return g, created
end

-- Shift-click or Suivre quête on a quest in no group: the end of the top group, starting Quêtes if there are none.
function Model:Track(questID)
    if self.world:InCombat() then
        return nil, "combat"
    end
    if not self:GroupOf(questID) then
        self:PlaceTracked(questID)
    end
    if self.world:HasQuest(questID) then
        self.world:AddWatch(questID)
    end
    return true
end

local function watchedSet(world)
    local list = world:WatchedList()
    local set = {}
    for _, id in ipairs(list) do
        set[id] = true
    end
    return set, list
end

-- Follows what changed in the game's list since the last look, whatever the events said, so several changes in
-- one frame are all seen and a watch flipped off and on within a frame, as DialogueUI does, changes nothing.
-- A placed quest the game never tracked, past its 25, stays put. Waits for login reconciliation and for combat
-- to end. Returns false if it had to wait.
function Model:SettleWatches()
    if not self.watched or self.world:InCombat() then
        return false
    end
    local now, list = watchedSet(self.world)
    for _, questID in ipairs(list) do
        if not self.watched[questID] and not self:GroupOf(questID) then
            self:PlaceTracked(questID)
        end
    end
    for questID in pairs(self.watched) do
        -- The game dropping the watch of a quest that left the log isn't the player stopping tracking it.
        if not now[questID] and self.world:HasQuest(questID) then
            local g = self:GroupOf(questID)
            if g then
                takeOut(self.db, questID)
                log("watch dropped: %d leaves group %d", questID, g.id)
            end
        end
    end
    self.watched = now
    return true
end

-- At login: quests in a group are tracked again, top group first so they get the game's 25 slots, then tracked
-- quests in no group join the top group. IDs missing from the log are left alone, because the log can read as
-- empty during login, and tracked ones among them are placed by the next settle once they show up.
function Model:Reconcile(logOrder)
    local inLog = {}
    for _, id in ipairs(logOrder) do
        inLog[id] = true
    end
    for _, g in ipairs(self.db.groups) do
        for _, id in ipairs(g.quests) do
            if inLog[id] and not self.world:IsWatched(id) then
                self.world:AddWatch(id)
            end
        end
    end
    for _, id in ipairs(logOrder) do
        if self.world:IsWatched(id) and not self:GroupOf(id) then
            self:PlaceTracked(id)
        end
    end
    self.watched = {}
    for _, id in ipairs(self.world:WatchedList()) do
        if inLog[id] then
            self.watched[id] = true
        end
    end
end

-- A quest accepted again keeps its old place and is tracked again. Otherwise one accepted from the NPC who just
-- took a placed quest takes that quest's slot. npc is that NPC's GUID, now the time in seconds.
-- Returns "saved" or "followup" when it placed the quest.
function Model:OnAccepted(questID, npc, now)
    if self:GroupOf(questID) then
        self.world:AddWatch(questID)
        return "saved"
    end
    if npc == nil or now == nil then
        return nil
    end
    for i = #self.turnIns, 1, -1 do
        local t = self.turnIns[i]
        if now - t.time > Model.FOLLOW_UP_SECONDS then
            table.remove(self.turnIns, i)
        elseif t.npc == npc then
            local g = self:GroupByID(t.groupID)
            if g then
                local index = math.min(t.index, #g.quests + 1)
                table.insert(g.quests, index, questID)
                t.index = index + 1
                self.world:AddWatch(questID)
                log("follow-up %d takes slot %d in group %d", questID, index, g.id)
                return "followup"
            end
        end
    end
    return nil
end

-- Only a confirmed turn-in of a non-repeatable quest forgets its place. A placed quest's slot is kept for a
-- moment, for a follow-up from the same NPC.
function Model:OnTurnedIn(questID, repeatable, npc, now)
    repeatable = repeatable or self.db.repeatable[questID] == true
    local g, index = self:GroupOf(questID)
    if not repeatable then
        takeOut(self.db, questID)
    end
    if g and npc ~= nil and now ~= nil then
        self.turnIns[#self.turnIns + 1] = { groupID = g.id, index = repeatable and index + 1 or index, npc = npc, time = now }
    end
end

-- A quest that left the log without a turn-in, abandoned, leaves its group at once, so accepted again it lands in
-- Journal. Ikar's ruling, 2026-11-09. Returns whether it was in one.
function Model:OnAbandoned(questID)
    local g = self:GroupOf(questID)
    if g then
        takeOut(self.db, questID)
        log("abandoned %d leaves group %d", questID, g.id)
    end
    return g ~= nil
end

-- Remembers which quests repeat while they're in the log, because out of it the game may not know.
function Model:NoteRepeatable(quests)
    for id, q in pairs(quests) do
        if q.repeatable then
            self.db.repeatable[id] = true
        end
    end
end

-- Forgets quests done for good. isDone(id) is true for a completed, non-repeatable quest. Repeatable quests seen
-- in the log are kept whatever isDone says, and forgotten once in no group and out of the log.
function Model:ForgetDone(isDone)
    local removed, placed = 0, {}
    for _, g in ipairs(self.db.groups) do
        for i = #g.quests, 1, -1 do
            local q = g.quests[i]
            if not self.world:HasQuest(q) and not self.db.repeatable[q] and isDone(q) then
                table.remove(g.quests, i)
                removed = removed + 1
            else
                placed[q] = true
            end
        end
    end
    for id in pairs(self.db.repeatable) do
        if not placed[id] and not self.world:HasQuest(id) then
            self.db.repeatable[id] = nil
        end
    end
    return removed
end
