-- Reads the game's quest log into plain records. The only file that walks C_QuestLog's rows.
local _, ns = ...

local QuestLog = {}
ns.QuestLog = QuestLog

-- Returns quests by ID and their IDs in log order. classify(header, key) gives the category, as Categories does.
-- Hidden, task and bounty entries aren't log quests and are skipped.
function QuestLog.Read(classify)
    local quests, order = {}, {}
    local header, headerKey
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info then
            if info.isHeader then
                header, headerKey = info.title, info.headerSortKey
            elseif not info.isHidden and not info.isTask and not info.isBounty and info.questID then
                local id = info.questID
                local category, headerKind = classify(header, headerKey)
                quests[id] = {
                    id = id,
                    title = info.title,
                    level = info.level,
                    difficultyLevel = info.difficultyLevel,
                    suggestedGroup = info.suggestedGroup,
                    frequency = info.frequency,
                    isAutoComplete = info.isAutoComplete,
                    isStory = info.isStory,
                    logIndex = index,
                    header = header,
                    -- The header's ID, the same in every language. See Categories.
                    headerKey = headerKey,
                    category = category,
                    headerKind = headerKind,
                    complete = C_QuestLog.IsComplete(id),
                    failed = C_QuestLog.IsFailed(id),
                    -- Any frequency but Default (0) repeats: daily, weekly, or reset by the scheduler.
                    repeatable = (info.frequency ~= nil and info.frequency ~= 0) or C_QuestLog.IsRepeatableQuest(id) == true,
                }
                order[#order + 1] = id
            end
        end
    end
    return quests, order
end
