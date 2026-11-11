-- A stand-in for the game's tracked list, combat and quest log, as the model sees them.
local T = KaLiQuestTests

function T.FakeWorld(questIDs)
    -- list: the game's tracked list in the order quests were added. npe: untracking refused, as in the NPE.
    local w = { list = {}, inLog = {}, combat = false, npe = false, limit = 25, adds = 0, removes = 0 }
    for _, id in ipairs(questIDs or {}) do
        w.inLog[id] = true
    end
    function w:IsWatched(id)
        for _, v in ipairs(self.list) do
            if v == id then
                return true
            end
        end
        return false
    end
    function w:WatchedList()
        local copy = {}
        for i, v in ipairs(self.list) do
            copy[i] = v
        end
        return copy
    end
    function w:Count()
        return #self.list
    end
    -- Like the game: no change if already watched, and nothing past the limit.
    function w:AddWatch(id)
        if self:IsWatched(id) then
            return true
        end
        if #self.list >= self.limit then
            return false
        end
        self.list[#self.list + 1] = id
        self.adds = self.adds + 1
        return true
    end
    function w:CanRemoveWatch()
        return not self.npe
    end
    function w:RemoveWatch(id)
        if self.npe then
            return false
        end
        for i = #self.list, 1, -1 do
            if self.list[i] == id then
                table.remove(self.list, i)
            end
        end
        self.removes = self.removes + 1
        return true
    end
    function w:InCombat()
        return self.combat
    end
    function w:HasQuest(id)
        return self.inLog[id] == true
    end
    return w
end

-- A model on fresh saved data, with quests 1 to n in the log and login reconciliation done.
function T.NewModel(n)
    local ns = KaLiQuestDev.ns
    local ids = {}
    for i = 1, n or 10 do
        ids[i] = i
    end
    local world = T.FakeWorld(ids)
    local db = ns.DB.Load(nil)
    local m = ns.Model.New(db, world, "Quêtes")
    m:Reconcile(ids)
    return m, world, db
end
